template_macro=./pcalib.base.mac
sim_dir=sim
dryrun=false

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

    local source_pos_default=7250

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
            if [[ $found == 1 ]]; then
                \qsub -N "$sim_id" -t ${start_idx}-${stop_idx} ../MaGe.qsub "$sim_id/macros/$sim_id"
            else
                print_log warn "'$sim_id' jobs look already running, won't submit"
            fi
        # elif ... add your cluster manager code here
        else
            print_log err "could not find suitable cluster manager"
        fi
    fi

    \cd - > /dev/null
}

process_simulation() {

    $dryrun && print_log warn "running in dry-run mode, no jobs will be actually sent"

    local nucleus=$1
    local source_number=$2
    local source_pos=$3
    local abs_length=$4
    local fiber_cov=$5
    local n_events_per_mac=$6
    local n_macros=$7
    local start_id=${8:-1}

    local name_id="${nucleus}-S${source_number}-${source_pos}-${abs_length}cm-${fiber_cov}cov"
    print_log info "creating '$name_id' macros"

    \mkdir -p "$sim_dir/$name_id"/{macros,output}

    for i in `seq -f "%05g" $start_id $(expr $start_id + $n_macros - 1)`; do
        dump_macro $nucleus $source_number $source_pos $abs_length $fiber_cov $n_events_per_mac "${name_id}/output/${name_id}-${i}.root" \
            > "$sim_dir/${name_id}/macros/${name_id}-${i}.mac"
    done

    submit_mage_jobs $name_id $start_id $(expr $start_id + $n_macros - 1)
}

submit_tier4izer_job() {

    local sim_id="t4z-${1}"
    local run_id="$2"
    local outname="$sim_dir/$1/${sim_id}-run${2}.root"
    local job="${sim_id}-run${2}"

    local do_rerun=false
    if [[ ! -f "$outname" ]]; then
        do_rerun=true
    fi

    if `which qsub &> /dev/null`; then
        \qstat -r 2>&1 | grep 'Full jobname:' | grep "$job" >/dev/null
        local found=$?
        if [[ $found == 1 ]]; then
            \qsub -N "$job" ./tier4izer.qsub "$sim_dir/$1/output" "$run_id" "$outname"
        else
            print_log warn "'$job' jobs look already running, won't submit"
        fi
    # elif ... add your cluster manager code here
    else
        print_log err "could not find suitable cluster manager"
    fi
}

submit_all_tier4izer_jobs() {
    for sim in `\ls "$sim_dir"`; do
        if [[ "$sim" =~ '^Bi214*' ]]; then
            submit_tier4izer_job $sim 76
        elif [[ "$sim" =~ '^Tl208*' ]]; then
            submit_tier4izer_job $sim 68
        fi
    done
}

transfer_to_lngs() {
    \rsync -vhut --progress `\find "$sim_dir" -name 't4z-*.root'` \
        `whoami`@gerda-login.lngs.infn.it:/nfs/gerda6/shared/gerda-simulations/gerda-pcalib-sim
}
