template_macro=./pcalib.base.mac
sim_dir=sim
dryrun=true

print_log() {
    case "$1" in
        "info")
            shift
            echo -e "\033[97;1mINFO:\033[0m $@"
            ;;
        "warn")
            shift
            >&2 echo -e "\033[33mWARNING:\033[0m $@"
            ;;
        "err")
            shift
            >&2 echo -e "\033[91mERROR:\033[0m $@"
            ;;
        *)
            print_log err "unknown logging level $1"
    esac
}

dump_macro() {

    local nucleus=$1
    local source_number=$2
    local source_pos=$3
    local abs_length=$4
    local fiber_cov=$5
    local n_events=$6
    local rootfile=$7

    local source_pos_default=725

    local sed_cmd=" \
        s|SETROOTNAME|$rootfile|g; \
        s|SETABSORPTION|$abs_length|g; \
        s|SETCOVERAGE|$fiber_cov|g; \
        s|SETEVENTS|$n_events|g; \
        s|SETSX|$(expr $source_number - 1)|g; \
    "

    for j in `seq 1 3`; do
       if [[ $source_number == $j ]]; then
           sed_cmd="${sed_cmd}s|SETS${j}POS|$source_pos|g; "
       else
           sed_cmd="${sed_cmd}s|SETS${j}POS|$source_pos_default|g; "
       fi
    done

    if [[ "$nucleus" == "Bi214" ]]; then
        sed_cmd="${sed_cmd}\
            s|SETZ|83|g; \
            s|SETA|214|g; \
            s|SETLOWCUT|1.80|g; \
            s|SETHIGHCUT|2.20|g; \
        "
    elif [[ "$nucleus" == "Tl208" ]]; then
        sed_cmd="${sed_cmd}\
            s|SETZ|81|g; \
            s|SETA|208|g; \
            s|SETLOWCUT|2.60|g; \
            s|SETHIGHCUT|2.630|g; \
        "
    fi

    \sed "$sed_cmd" "$template_macro"
}


submit_mage_jobs() {

    local sim_id="$1"
    local start_idx=$2
    local stop_idx=$3

    \cd $sim_dir

    # TODO: improve this and start only missing sims
    local do_rerun=false
    for i in `seq -f "%05g" $start_idx $stop_idx`; do
        if [[ ! -f "$sim_id/output/${sim_id}-${i}.root" ]]; then
            do_rerun=true
        fi
    done

    if $do_rerun; then
        print_log info "submitting '$sim_id' jobs"
    else
        print_log warn "'$sim_id' jobs look up to date, won't submit"
    fi

    if [[ $dryrun == false ]]; then
        if `which qsub &> /dev/null`; then
            \qstat -r 2>&1 | grep 'Full jobname:' | grep "$sim_id" >/dev/null
            local found=$?
            if $found; then
                print_log warn "'$sim_id' jobs look already running, won't submit"
            else
                \qsub -N "$sim_id" -t ${start_idx}-${stop_idx} -- ./MaGe.qsub "$sim_id"
            fi
        # elif ... add your cluster manager code here
        else
            print_log err "could not find suitable cluster manager"
        fi
    fi

    \cd - > /dev/null
}

process_simulation() {

    print_log warn "running in dry-run mode, no jobs will be actually sent"

    local nucleus=$1
    local source_number=$2
    local source_pos=$3
    local abs_length=$4
    local fiber_cov=$5
    local n_events_per_mac=$6
    local n_macros=$7
    local start_id=${8:-0}

    local name_id="${nucleus}-S${source_number}-${source_pos}-${abs_length}cm-${fiber_cov}cov"
    print_log info "creating '$name_id' macros"

    \mkdir -p "$sim_dir/$name_id"/{macros,output}

    for i in `seq -f "%05g" $start_id $(expr $start_id + $n_macros - 1)`; do
        dump_macro $nucleus $source_number $source_pos $abs_length $fiber_cov $n_events_per_mac "${name_id}/output/${name_id}-${i}.root" \
            > "$sim_dir/${name_id}/macros/${name_id}-${i}.mac"
    done

    submit_mage_jobs "$sim_dir/${name_id}/macros/${name_id}" $start_id $(expr $start_id + $n_macros - 1)
}
