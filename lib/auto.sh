# Setup-mode detection: Auto (file-based) and Guided (user-picked tech stack) both fill the same
# DETECTED_AGENTS/DETECTED_SKILLS/DETECTED_NOTES arrays, just via different triggers — see
# resolve_setup_mode()/resolve_guided_stack() below. Auto is offered as a wizard choice whenever
# there's something in the target directory to detect it from (gated by the entrypoint via
# OFFER_SETUP_MODE — see install.sh). Every DETECTED_* entry from Auto is backed by a concrete
# file-level signal (recorded in DETECTED_NOTES) so the wizard can show its work instead of
# silently guessing; Guided's notes are just the label of whatever the user picked.
#
# Detection runs in two phases, kept deliberately separate: _project_scan() (below) gathers raw,
# generic facts about the target directory exactly once — what build files exist, whether
# src/main/kotlin is there, and so on — into the PROJECT_* globals. run_detection() then calls
# every category's detect_<name>() function (one per file in lib/detect/*.sh, discovered by
# reflection — see run_detection()), each of which reads those PROJECT_* facts and independently
# decides whether to add to DETECTED_AGENTS/DETECTED_SKILLS/DETECTED_NOTES. A category never scans
# the filesystem itself — only this file's _project_scan() does that.
#
# Detection is intentionally conservative: only agents/skills tied to a concrete, checkable signal
# get auto-selected. Generic agents with no file-level signature (architect, doc-writer) and the
# on-demand design-patterns skill are never auto-selected — add them manually via the picker or
# -a/-s. clean-code is the one exception to "on-demand": it's language-agnostic and listed in every
# language-writing agent's own `skills:` frontmatter (spring-boot-engineer/reviewer,
# angular-engineer/reviewer — see dist/skills/clean-code/SKILL.md), so _kotlin_apply()/
# _java_apply()/_angular_apply() (lib/detect/kotlin.sh, java.sh, angular.sh) each add it directly
# rather than requiring a separate pick — whichever language gets selected brings it along. Every
# category must add a DETECTED_NOTES line explaining itself — no silent additions.
#
# bash 3.2 gotcha (macOS's default /bin/bash): under `set -u`, bare-expanding an empty *named*
# array — "${arr[@]}" where arr=() — throws "unbound variable", even in a plain for-loop or as a
# function argument. (The special "$@" is never affected by this, only named arrays.) Detection
# routinely produces empty arrays (e.g. a Docker-only project has no matching skill), so every
# array expansion in this file and in lib/detect/*.sh is guarded with a `[[ ${#arr[@]} -gt 0 ]]`
# length check first (or goes through _grep_project_files, which already guards for you) — never
# expand a DETECTED_*/PROJECT_* array bare.

# True if any of the given (possibly-nonexistent) files match an ERE pattern. Safe to call with
# zero file arguments (loops over "$@", which — unlike a named array — never triggers the bash 3.2
# empty-array bug under `set -u`).
_detect_grep_any() {
  local pattern="$1"; shift
  local f
  for f in "$@"; do
    [[ -f "$f" ]] || continue
    grep -qE "$pattern" "$f" 2>/dev/null && return 0
  done
  return 1
}

# Finds files matching one or more -iname patterns under maxdepth, pruning heavy directories.
# Prints matches one per line; empty output means no match. Always called with >=1 pattern.
_detect_find() {
  local maxdepth="$1"; shift
  local expr=() first=true pat
  for pat in "$@"; do
    if $first; then expr+=(-iname "$pat"); first=false
    else expr+=(-o -iname "$pat"); fi
  done
  find . -maxdepth "$maxdepth" \
    \( -name node_modules -o -name .git -o -name build -o -name dist -o -name target -o -name vendor \) -prune -o \
    \( "${expr[@]}" \) -print 2>/dev/null
}

_detect_any_dir() {
  local d
  for d in "$@"; do [[ -d "$d" ]] && return 0; done
  return 1
}

# True if a directory whose path ends in the given suffix exists under maxdepth, pruning heavy
# directories — e.g. `_detect_path_dir 4 'src/main/kotlin'` matches both ./src/main/kotlin (a
# plain single-module project) and ./backend/src/main/kotlin (a backend/frontend monorepo split,
# the common layout for this toolkit's own target projects). Path-based (not -iname) so it doesn't
# false-positive on an unrelated directory that happens to be named "kotlin".
_detect_path_dir() {
  local maxdepth="$1" suffix="$2"
  [[ -n "$(find . -maxdepth "$maxdepth" \
       \( -name node_modules -o -name .git -o -name build -o -name dist -o -name target -o -name vendor \) -prune -o \
       -type d -path "*/$suffix" -print -quit 2>/dev/null)" ]]
}

# Greps for an ERE `pattern` across every element of one or more PROJECT_*_FILES arrays, given BY
# NAME (not by value) — e.g. `_grep_project_files 'postgresql' PROJECT_BUILD_FILES
# PROJECT_COMPOSE_FILES PROJECT_CONFIG_FILES`. Exists so category files in lib/detect/ never have
# to repeat the bash-3.2 empty-array guard themselves: safe with any mix of empty/non-empty arrays.
#
# Uses `eval` for name-indirection because bash 3.2 has no `local -n`/namerefs (bash 4.3+) and no
# associative arrays (bash 4.0+) to fall back on. Verified against a real /bin/bash 3.2.57, incl.
# filenames containing spaces and a literal `$`. A typo'd/undefined array name fails loudly
# ("unbound variable") rather than silently behaving as empty — treat that as a feature, not a
# footgun, when writing a new category file.
_grep_project_files() {
  local pattern="$1"; shift
  local arrname n
  for arrname in "$@"; do
    eval "n=\${#${arrname}[@]}"
    [[ $n -gt 0 ]] || continue
    eval "_detect_grep_any \"\$pattern\" \"\${${arrname}[@]}\"" && return 0
  done
  return 1
}

# "Step 1: analyze the directory" — gathers raw, concrete file-level facts about the target project
# exactly once, before any category module runs. Category modules (lib/detect/*.sh) never call
# find/grep against the filesystem themselves — they only read these PROJECT_* globals. This keeps
# "what files exist" (this function) separate from "what that implies" (one function per category).
_project_scan() {
  PROJECT_BUILD_FILES=()
  while IFS= read -r f; do PROJECT_BUILD_FILES+=("$f"); done \
    < <(_detect_find 2 'build.gradle.kts' 'build.gradle' 'pom.xml')

  PROJECT_COMPOSE_FILES=()
  while IFS= read -r f; do PROJECT_COMPOSE_FILES+=("$f"); done \
    < <(_detect_find 2 'docker-compose*.yml' 'docker-compose*.yaml' 'compose.yml' 'compose.yaml')

  PROJECT_CONFIG_FILES=()
  while IFS= read -r f; do PROJECT_CONFIG_FILES+=("$f"); done \
    < <(_detect_find 4 'application*.yml' 'application*.yaml' 'application*.properties')

  PROJECT_DOCKERFILES=()
  while IFS= read -r f; do PROJECT_DOCKERFILES+=("$f"); done < <(_detect_find 2 'Dockerfile*')

  PROJECT_ANGULAR_JSON_FILES=()
  while IFS= read -r f; do PROJECT_ANGULAR_JSON_FILES+=("$f"); done < <(_detect_find 2 'angular.json')

  PROJECT_PACKAGE_JSON_FILES=()
  while IFS= read -r f; do PROJECT_PACKAGE_JSON_FILES+=("$f"); done < <(_detect_find 2 'package.json')

  PROJECT_CHART_FILES=()
  while IFS= read -r f; do PROJECT_CHART_FILES+=("$f"); done < <(_detect_find 3 'Chart.yaml')

  PROJECT_OPENAPI_FILES=()
  while IFS= read -r f; do PROJECT_OPENAPI_FILES+=("$f"); done \
    < <(_detect_find 3 'openapi.yml' 'openapi.yaml' 'swagger.yml' 'swagger.yaml')

  PROJECT_ANSIBLE_CFG_FILES=()
  while IFS= read -r f; do PROJECT_ANSIBLE_CFG_FILES+=("$f"); done < <(_detect_find 2 'ansible.cfg')

  PROJECT_ANSIBLE_INVENTORY_FILES=()
  while IFS= read -r f; do PROJECT_ANSIBLE_INVENTORY_FILES+=("$f"); done \
    < <(_detect_find 3 'hosts.ini' 'inventory.ini')

  PROJECT_HAS_KOTLIN_SRC=false; _detect_path_dir 4 'src/main/kotlin' && PROJECT_HAS_KOTLIN_SRC=true
  PROJECT_HAS_JAVA_SRC=false;   _detect_path_dir 4 'src/main/java'   && PROJECT_HAS_JAVA_SRC=true
  PROJECT_HAS_K8S_DIR=false
  _detect_any_dir helm charts k8s kubernetes && PROJECT_HAS_K8S_DIR=true
  PROJECT_HAS_ANSIBLE_DIR=false
  _detect_any_dir ansible && PROJECT_HAS_ANSIBLE_DIR=true
  return 0
}

# "Step 2: hand the analysis to each module." Every detect_<name>() function — one per
# lib/detect/*.sh file, sourced by install.sh before this runs — is discovered by reflection
# (declare -F), not a hardcoded list here or anywhere else: the same "glob it, don't register it"
# philosophy as dist/agents/*.md / dist/skills/*/ (see discover_items() in lib/selection.sh).
# Adding a category means adding a lib/detect/<name>.sh file defining detect_<name>() — nothing
# else to wire up.
#
# Naming convention is load-bearing: ANY function whose name starts with "detect_" gets invoked
# directly with no arguments by the loop below. Give private helpers inside a lib/detect/*.sh file
# a leading underscore (e.g. _kotlin_gradle_plugin_present) instead, or they'll be wrongly swept up
# and run as if they were their own category.
run_detection() {
  DETECTED_AGENTS=()
  DETECTED_SKILLS=()
  DETECTED_NOTES=()

  _project_scan

  local fns=()
  while IFS= read -r fn; do fns+=("$fn"); done \
    < <(declare -F | awk '{print $3}' | grep '^detect_' | sort)

  if [[ ${#fns[@]} -gt 0 ]]; then
    local fn
    for fn in "${fns[@]}"; do
      "$fn"
    done
  fi

  # De-dupe (more than one category can legitimately add the same agent/skill — e.g. a mixed
  # multi-module project could in principle trip more than one backend rule).
  DETECTED_AGENTS=($(printf '%s\n' "${DETECTED_AGENTS[@]-}" | awk 'NF && !seen[$0]++'))
  DETECTED_SKILLS=($(printf '%s\n' "${DETECTED_SKILLS[@]-}" | awk 'NF && !seen[$0]++'))
  return 0
}

# Applies detection results to SELECTED_AGENTS/SELECTED_SKILLS, without overriding either that was
# already pinned via -a/-s — same "flags win, auto fills in the rest" precedence used for the git
# workflow flags. "none" is an explicit marker (see resolve() in selection.sh) meaning "detected
# nothing for this category, install zero" — distinct from "" (not yet decided).
apply_detected_selection() {
  if [[ -z "$SELECTED_AGENTS" ]]; then
    if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
      SELECTED_AGENTS=$(printf '%s,' "${DETECTED_AGENTS[@]}" | sed 's/,$//')
    else
      SELECTED_AGENTS="none"
    fi
  fi
  if [[ -z "$SELECTED_SKILLS" ]]; then
    if [[ ${#DETECTED_SKILLS[@]} -gt 0 ]]; then
      SELECTED_SKILLS=$(printf '%s,' "${DETECTED_SKILLS[@]}" | sed 's/,$//')
    else
      SELECTED_SKILLS="none"
    fi
  fi
  return 0
}

print_detected_notes() {
  [[ ${#DETECTED_NOTES[@]} -eq 0 ]] && return 0
  echo "Detected in this project:"
  local note
  for note in "${DETECTED_NOTES[@]}"; do
    echo "  - $note"
  done
  echo ""
  return 0
}

# The wizard's leading "Auto / Guided / Manual" question. No-op unless the entrypoint set
# OFFER_SETUP_MODE=true (nothing already pinned via -a/-s/--auto, and this isn't --no-confirm).
# "Auto" only appears as an option when something was actually detected — Guided and Manual are
# always available regardless of what's in the directory.
#
# Loops on its own leading question so that going back out of a Guided sub-selection (Esc during
# resolve_guided_stack) redisplays this question instead of exiting the step entirely — only Esc on
# the leading question itself is a real WIZARD_BACK, propagated to run_wizard_from() (index 0, so it
# just clamps back to itself — there's no step before Mode). Every (re-)entry, including a later
# revisit after the user went further and came back, resets AUTO_MODE/GUIDED_MODE/SELECTED_AGENTS/
# SELECTED_SKILLS and restores DETECTED_*/DETECTED_NOTES from the ORIG_DETECTED_* snapshot install.sh
# took right after run_detection() ran once at start-up: without the restore, re-picking Auto after
# having visited Guided (which overwrites DETECTED_* with whatever the user picked there) would apply
# the Guided leftovers instead of real file detection. This reset is always safe here specifically
# because OFFER_SETUP_MODE is only ever true when both SELECTED_AGENTS and SELECTED_SKILLS started
# out empty (see install.sh) — there's never a -a/-s flag value to preserve.
resolve_setup_mode() {
  if ! $OFFER_SETUP_MODE; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi

  step "$STEP_IDX_MODE" "${WIZARD_STEPS[$STEP_IDX_MODE]}"

  DETECTED_AGENTS=(); [[ ${#ORIG_DETECTED_AGENTS[@]} -gt 0 ]] && DETECTED_AGENTS=("${ORIG_DETECTED_AGENTS[@]}")
  DETECTED_SKILLS=(); [[ ${#ORIG_DETECTED_SKILLS[@]} -gt 0 ]] && DETECTED_SKILLS=("${ORIG_DETECTED_SKILLS[@]}")
  DETECTED_NOTES=(); [[ ${#ORIG_DETECTED_NOTES[@]} -gt 0 ]] && DETECTED_NOTES=("${ORIG_DETECTED_NOTES[@]}")

  local opt_auto="Auto — install & configure what was detected below (recommended)"
  local opt_guided="Guided — tell me your tech stack, I'll pick the agents/skills"
  local opt_manual="Manual — pick agents and skills yourself"
  local options=()

  if [[ ${#DETECTED_AGENTS[@]} -gt 0 ]]; then
    print_detected_notes
    options+=("$opt_auto")
  fi
  options+=("$opt_guided" "$opt_manual")

  while true; do
    local choice
    ask_choice "How do you want to set this up?" "${options[@]}"
    choice="$PICK_RESULT"
    if $WIZARD_BACK; then
      WIZARD_SKIPPED=false
      return 0
    fi

    case "$choice" in
      "$opt_auto")
        AUTO_MODE=true; GUIDED_MODE=false
        SELECTED_AGENTS=""; SELECTED_SKILLS=""
        apply_detected_selection
        WIZARD_SKIPPED=false; WIZARD_BACK=false
        return 0
        ;;
      "$opt_guided")
        AUTO_MODE=false; GUIDED_MODE=true
        SELECTED_AGENTS=""; SELECTED_SKILLS=""
        resolve_guided_stack
        $WIZARD_BACK && continue   # re-show the mode question instead of exiting the step
        apply_detected_selection
        WIZARD_SKIPPED=false
        return 0
        ;;
      *) # Manual — nothing more to do here; resolve_agent_selection/resolve_skill_selection prompt.
        AUTO_MODE=false; GUIDED_MODE=false
        SELECTED_AGENTS=""; SELECTED_SKILLS=""
        WIZARD_SKIPPED=false; WIZARD_BACK=false
        return 0
        ;;
    esac
  done
}

# Guided mode: one multi-select screen per group (Frontend/Backend/Database/DevOps — see
# GROUP_ORDER below), each listing the human-readable labels (_<name>_label(), one per
# lib/detect/*.sh file — discovered the same "no registry" way as run_detection(), just keyed off
# the "_apply" suffix instead of the "detect_" prefix) of the categories that belong to it
# (_<name>_group(), _<name>_label()'s sibling — see the comment on _kotlin_label() in
# lib/detect/kotlin.sh). Whichever labels the user picks get their _<name>_apply() called directly
# — the exact same contribution code Auto's detect_<name>() calls, just triggered by a user choice
# instead of a file signal. The DETECTED_NOTES line for a Guided pick is just its label (there's no
# file evidence to cite).
#
# The four screens are asked in order with the same idx+direction traversal run_wizard_from()
# (lib/ui.sh) uses across whole wizard steps, reused here at a smaller scale because the shape is
# identical: an ordered list of screens, some possibly empty (skipped in whichever direction is
# already in effect), where Esc on a screen steps back to the previous non-empty one. Esc on the
# very first screen shown propagates WIZARD_BACK out of this function unchanged, which
# resolve_setup_mode's caller-side check (`$WIZARD_BACK && continue`) turns into "re-show the
# Auto/Guided/Manual question" — exactly like ask_git_workflow_details() propagating out of its own
# first question to resolve_git_workflow() (lib/git_workflow.sh).
#
# A category with no _<name>_group() function falls back to the "Other" group, shown as its own
# screen after the four named ones — so a category file that forgets this function still surfaces
# in Guided mode instead of silently vanishing. GROUP_ORDER is the one hand-maintained piece: it
# fixes the screen order for the four named groups; any other group name encountered (a future
# fifth group, or "Other") is appended after, in first-seen order.
#
# Resets DETECTED_AGENTS/SKILLS/NOTES first: run_detection() already ran once (to know whether to
# offer "Auto" at all) and may have found things, but Guided is explicitly the "I'll tell you
# exactly what to install" mode — its result must reflect only what the user picks here, not a mix
# of that plus whatever file-based detection happened to notice.
resolve_guided_stack() {
  step "$STEP_IDX_GUIDED" "${WIZARD_STEPS[$STEP_IDX_GUIDED]}"

  DETECTED_AGENTS=()
  DETECTED_SKILLS=()
  DETECTED_NOTES=()

  local apply_fns=() labels=() cat_groups=() fn name
  while IFS= read -r fn; do apply_fns+=("$fn"); done \
    < <(declare -F | awk '{print $3}' | grep '_apply$' | sort)

  if [[ ${#apply_fns[@]} -eq 0 ]]; then
    warn "No tech-stack options available — skipping guided selection."
    WIZARD_BACK=false
    return 0
  fi

  for fn in "${apply_fns[@]}"; do
    name="${fn#_}"; name="${name%_apply}"
    labels+=("$("_${name}_label")")
    if declare -F "_${name}_group" >/dev/null 2>&1; then
      cat_groups+=("$("_${name}_group")")
    else
      cat_groups+=("Other")
    fi
  done

  local group_order=(Frontend Backend Database DevOps) g known o
  for g in "${cat_groups[@]}"; do
    known=false
    for o in "${group_order[@]}"; do [[ "$o" == "$g" ]] && { known=true; break; }; done
    $known || group_order+=("$g")
  done

  local gi=0 direction=1
  while [[ $gi -ge 0 && $gi -lt ${#group_order[@]} ]]; do
    local group="${group_order[$gi]}"
    local group_labels=() group_indices=() i
    for i in "${!cat_groups[@]}"; do
      if [[ "${cat_groups[$i]}" == "$group" ]]; then
        group_labels+=("${labels[$i]}")
        group_indices+=("$i")
      fi
    done

    if [[ ${#group_labels[@]} -eq 0 ]]; then
      gi=$((gi + direction))
      continue
    fi

    pick "$group" "${group_labels[@]}"
    if $WIZARD_BACK; then
      direction=-1
      gi=$((gi - 1))
      [[ $gi -lt 0 ]] && return 0   # nothing earlier within Guided — propagate to the Mode question
      continue
    fi
    direction=1

    local selection="$PICK_RESULT" chosen=() choice
    IFS=',' read -ra chosen <<< "$selection"
    for choice in "${chosen[@]}"; do
      for i in "${group_indices[@]}"; do
        if [[ "${labels[$i]}" == "$choice" ]]; then
          "${apply_fns[$i]}"
          DETECTED_NOTES+=("${labels[$i]}")
        fi
      done
    done

    gi=$((gi + 1))
  done

  DETECTED_AGENTS=($(printf '%s\n' "${DETECTED_AGENTS[@]-}" | awk 'NF && !seen[$0]++'))
  DETECTED_SKILLS=($(printf '%s\n' "${DETECTED_SKILLS[@]-}" | awk 'NF && !seen[$0]++'))
  # Deduped too, unlike the arrays above ever needed to be before Guided had internal back
  # navigation: revisiting a screen after backing up and choosing forward again re-applies its
  # picks, and while duplicate agent/skill names are harmless (deduped here same as always),
  # duplicate note lines would show the same category twice in the printed "Detected in this
  # project" summary.
  DETECTED_NOTES=($(printf '%s\n' "${DETECTED_NOTES[@]-}" | awk 'NF && !seen[$0]++'))
  WIZARD_BACK=false
  return 0
}
