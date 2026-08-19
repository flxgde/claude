# Kotlin backend — fires purely on concrete Kotlin evidence (src/main/kotlin), independent of
# whether a Spring Boot dependency is also present. Split out of the old combined Spring/Kotlin
# check specifically so kotlin-patterns stops being added to pure-Java projects — see java.sh.
#
# Four functions, same shape every lib/detect/*.sh file follows (see run_detection()/
# resolve_guided_stack() in lib/auto.sh for how each is discovered and called):
#   detect_<name>()  — Auto entry point (reflection-discovered by the "detect_" prefix). Checks
#                       PROJECT_* facts; on a hit, calls _<name>_apply() and adds its own
#                       evidence-specific DETECTED_NOTES line.
#   _<name>_apply()  — pure contribution (agents/skills only, no notes) — reused by both Auto and
#                       Guided mode, which is why it can't hardcode an evidence-based note itself.
#   _<name>_label()  — human-readable stack-option text shown in Guided mode's multi-select
#                       picker, and reused verbatim as the DETECTED_NOTES line when the user picks
#                       it there instead of it being auto-detected.
#   _<name>_group()  — which of Guided mode's per-group screens (Frontend/Backend/Database/DevOps
#                       — see GROUP_ORDER in resolve_guided_stack()) this category's label appears
#                       under. A category with no _<name>_group() function falls back to "Other",
#                       shown as its own screen after the four named ones — so a new category file
#                       that forgets this function still shows up in Guided mode, just ungrouped,
#                       rather than silently vanishing.
_kotlin_label() { echo "Kotlin backend (Spring Boot)"; }
_kotlin_group() { echo "Backend"; }

_kotlin_apply() {
  DETECTED_AGENTS+=(spring-boot-engineer spring-boot-reviewer)
  # clean-code is language-agnostic (see dist/skills/clean-code/SKILL.md) and listed in both
  # spring-boot-engineer's and spring-boot-reviewer's own `skills:` frontmatter — it belongs
  # wherever those agents do, not behind its own detection signal.
  DETECTED_SKILLS+=(kotlin-patterns logging-patterns clean-code)
}

detect_kotlin() {
  if $PROJECT_HAS_KOTLIN_SRC; then
    _kotlin_apply
    DETECTED_NOTES+=("Kotlin backend — src/main/kotlin")
  fi
  return 0
}
