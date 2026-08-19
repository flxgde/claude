# Git-workflow policy: interactively wizarded (leading question + optional 5-question "Custom"
# breakdown) or fully driven by --use-git/--auto-commit/--use-mrs/--create-mrs/--push-direct, then
# rendered into AGENTS.md's "## Git Workflow" section via render_git_workflow_policy(). No-op
# for --uninstall (it deletes AGENTS.md outright, doesn't care about its content).

# Drives the five questions with a plain index so Esc on any one of them steps back to the
# previous one instead of just re-asking itself or bailing out. Each field still honors its own
# CLI-flag preset (GIT_USE_PRESET etc. — captured once in install.sh from the original
# --use-git/--auto-commit/--use-mrs/--create-mrs/--push-direct values, before anything here mutates
# them) as a permanent skip in both directions — stepping back is never allowed to land on, or
# re-ask, a question the user already answered on the command line. Unlike resolve_best_practices'/
# resolve_agent_selection's single-picker steps, a non-preset field here is always re-asked
# unconditionally on every visit (no `[[ -z "$GIT_X" ]]` guard) rather than needing an explicit
# reset-on-reentry — since this loop only ever runs its questions in strict order, "reached this
# index again" already means "the user wants to answer it again."
#
# Sets WIZARD_BACK to true only when Esc is pressed on the very first in-scope question (index 0,
# GIT_USE — or whichever question a CLI-preset GIT_USE skips forward past first) — i.e. exactly
# when there's no earlier question *within this breakdown* left to step back to. The caller
# (resolve_git_workflow) decides what that means: re-show the leading No-git/Commit/Custom question
# when reached via "Custom...", or propagate further back to the previous wizard step when reached
# via --git-wizard (which has no leading question to fall back to).
ask_git_workflow_details() {
  local idx=0
  while true; do
    case $idx in
      0)
        if $GIT_USE_PRESET; then idx=1; continue; fi
        ask_choice "Does the agent work with git in this project?" "no" "yes"
        if $WIZARD_BACK; then
          return 0
        fi
        GIT_USE="$PICK_RESULT"
        if [[ "$GIT_USE" == "no" ]]; then
          GIT_AUTOCOMMIT="no"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no"
          return 0
        fi
        idx=1
        ;;
      1)
        if $GIT_AUTOCOMMIT_PRESET; then idx=2; continue; fi
        ask_choice "Commit its own completed work automatically, without asking?" "yes" "no"
        if $WIZARD_BACK; then
          $GIT_USE_PRESET && return 0
          idx=0; continue
        fi
        GIT_AUTOCOMMIT="$PICK_RESULT"
        idx=2
        ;;
      2)
        if $GIT_USE_MRS_PRESET; then idx=3; continue; fi
        ask_choice \
          "Work via feature branch + merge/pull request, instead of the current branch directly?" \
          "no" "yes"
        if $WIZARD_BACK; then idx=1; continue; fi
        GIT_USE_MRS="$PICK_RESULT"
        idx=3
        ;;
      3)
        if [[ "$GIT_USE_MRS" != "yes" ]]; then GIT_CREATE_MRS="no"; idx=4; continue; fi
        if $GIT_CREATE_MRS_PRESET; then idx=4; continue; fi
        ask_choice "Open the merge/pull request itself (e.g. gh/glab), not just push the branch?" \
          "no" "yes"
        if $WIZARD_BACK; then idx=2; continue; fi
        GIT_CREATE_MRS="$PICK_RESULT"
        idx=4
        ;;
      4)
        if $GIT_PUSH_DIRECT_PRESET; then WIZARD_BACK=false; return 0; fi
        ask_choice "Allow direct pushes to the main/trunk branch?" "no" "yes"
        if $WIZARD_BACK; then idx=3; continue; fi
        GIT_PUSH_DIRECT="$PICK_RESULT"
        return 0
        ;;
    esac
  done
}

# Interactively, this always leads with one question offering "no git" as the default (safest —
# never touches git at all), "commit locally" as a named alternative, and "Custom..." to drop into
# the full five-question breakdown — rather than asking five separate questions up front. Explicit
# --use-git/--auto-commit/--use-mrs/--create-mrs/--push-direct flags always win and skip whichever
# question they answer; passing any of them skips the leading question entirely (the CLI is itself
# "custom" already). --git-wizard jumps straight to the five-question breakdown, skipping the
# leading question.
#
# This question is always asked interactively, regardless of which setup mode (Auto/Guided/Manual)
# was picked for agents/skills — AGENTS.md's "Git Workflow" section is a separate concern from
# which agents/skills get installed, and this is the one place it gets configured. Only
# --no-confirm (silent mode — no prompts at all) or explicit git flags on the command line skip it.
#
# Checks GIT_ANY_FLAG_PRESET (captured once in install.sh from the original CLI flag values, right
# after argument parsing) rather than testing the live GIT_* variables for "were flags given" — this
# function fills every GIT_* var with a default at its own end, so re-testing them on a later
# revisit (go back, then forward again) would see them all non-empty and wrongly treat that as
# "flags were preset," skipping the question it should be re-asking.
#
# Loops on its own leading question the same way resolve_setup_mode() loops on Auto/Guided/Manual:
# Esc during the "Custom..." breakdown (ask_git_workflow_details' own WIZARD_BACK, propagated only
# when Esc lands on that breakdown's first in-scope question) redisplays this leading question
# instead of exiting the step; only Esc on the leading question itself — or anywhere in the
# breakdown when reached via --git-wizard, which has no leading question — is a real WIZARD_BACK
# propagated out to run_wizard_from(), stepping back to Best Practices.
resolve_git_workflow() {
  if $UNINSTALL; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    return 0
  fi

  if $NO_CONFIRM || $GIT_ANY_FLAG_PRESET; then
    WIZARD_SKIPPED=true; WIZARD_BACK=false
    [[ -z "$GIT_USE" ]]          && GIT_USE="no"
    [[ -z "$GIT_AUTOCOMMIT" ]]   && GIT_AUTOCOMMIT="no"
    [[ -z "$GIT_USE_MRS" ]]      && GIT_USE_MRS="no"
    [[ -z "$GIT_CREATE_MRS" ]]   && GIT_CREATE_MRS="no"
    [[ -z "$GIT_PUSH_DIRECT" ]]  && GIT_PUSH_DIRECT="no"
    return 0
  fi

  step "$STEP_IDX_GIT" "${WIZARD_STEPS[$STEP_IDX_GIT]}"

  if $GIT_WIZARD; then
    ask_git_workflow_details
    if $WIZARD_BACK; then
      WIZARD_SKIPPED=false
      return 0
    fi
  else
    local OPT_NOGIT="No git (recommended)"
    local OPT_COMMIT="Commit automatically, no push or MRs"
    local OPT_CUSTOM="Custom..."
    while true; do
      local workflow_choice
      ask_choice "How should the agent handle git in this project?" \
        "$OPT_NOGIT" "$OPT_COMMIT" "$OPT_CUSTOM"
      if $WIZARD_BACK; then
        WIZARD_SKIPPED=false
        return 0
      fi
      workflow_choice="$PICK_RESULT"
      case "$workflow_choice" in
        "$OPT_COMMIT")
          GIT_USE="yes"; GIT_AUTOCOMMIT="yes"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no"
          break ;;
        "$OPT_CUSTOM")
          ask_git_workflow_details
          $WIZARD_BACK && continue   # re-show the leading No-git/Commit/Custom question
          break ;;
        *)
          # OPT_NOGIT, and the safe fallback for anything unexpected — never touches git.
          GIT_USE="no"; GIT_AUTOCOMMIT="no"; GIT_USE_MRS="no"; GIT_CREATE_MRS="no"; GIT_PUSH_DIRECT="no"
          break ;;
      esac
    done
  fi

  [[ -z "$GIT_USE" ]]          && GIT_USE="no"
  [[ -z "$GIT_AUTOCOMMIT" ]]   && GIT_AUTOCOMMIT="no"
  [[ -z "$GIT_USE_MRS" ]]      && GIT_USE_MRS="no"
  [[ -z "$GIT_CREATE_MRS" ]]   && GIT_CREATE_MRS="no"
  [[ -z "$GIT_PUSH_DIRECT" ]]  && GIT_PUSH_DIRECT="no"
  WIZARD_SKIPPED=false
  WIZARD_BACK=false
  return 0
}

# Renders the "## Git Workflow" bullet list from the wizard answers above.
render_git_workflow_policy() {
  if [[ "$GIT_USE" != "yes" ]]; then
    echo "- This project's workflow does not involve git — do not run git commands or create commits."
    return
  fi

  if [[ "$GIT_AUTOCOMMIT" == "yes" ]]; then
    echo "- After a full implementation cycle (feature code + passing tests), commit automatically — no need to ask."
    echo "- Only after tests pass — never commit a broken state."
    echo "- Write a meaningful commit message: imperative mood, concise subject line, body if the why needs explaining."
    echo "- Stage only the files relevant to the feature — never \`git add .\` blindly."
  else
    echo "- Always ask before committing — do not commit automatically, even after a completed feature cycle."
  fi

  if [[ "$GIT_USE_MRS" == "yes" ]]; then
    echo "- Work on a feature branch, not directly on the main/trunk branch."
    if [[ "$GIT_CREATE_MRS" == "yes" ]]; then
      echo "- Once the branch is pushed and ready for review, open the merge/pull request yourself (e.g. \`gh pr create\` / \`glab mr create\`)."
    else
      echo "- Push the feature branch, but leave opening the merge/pull request to the user."
    fi
  else
    echo "- Do not use a branch + merge/pull-request workflow — work directly on the current branch."
  fi

  if [[ "$GIT_PUSH_DIRECT" == "yes" ]]; then
    echo "- Direct pushes to the main/trunk branch are allowed when appropriate."
  else
    echo "- Never push directly to the main/trunk branch."
  fi
}

# One-line summary shown in the install plan.
git_workflow_summary() {
  if [[ "$GIT_USE" != "yes" ]]; then
    echo "no git"
    return
  fi
  local parts=()
  [[ "$GIT_AUTOCOMMIT" == "yes" ]] && parts+=("auto-commit") || parts+=("ask before commit")
  if [[ "$GIT_USE_MRS" == "yes" ]]; then
    [[ "$GIT_CREATE_MRS" == "yes" ]] && parts+=("opens MRs itself") || parts+=("pushes branch (no MR)")
  else
    parts+=("no branch/MR workflow")
  fi
  [[ "$GIT_PUSH_DIRECT" == "yes" ]] && parts+=("direct push to main allowed") || parts+=("no direct push to main")

  local out="" p
  for p in "${parts[@]}"; do
    [[ -z "$out" ]] && out="$p" || out="$out, $p"
  done
  echo "$out"
}
