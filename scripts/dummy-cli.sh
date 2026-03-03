#!/bin/bash
# Dummy CLI script for testing PromptRefine plugin
# This mimics an LLM CLI by reading stdin, processing it, and outputting with conversational text + markdown blocks

# Read all stdin
INPUT=$(cat)

# Get the content after the separator (simulate processing)
PROMPT_CONTENT=$(echo "$INPUT" | sed -n '/--- PROMPT TO REFINE ---/,$p' | tail -n +2)

# Create a refined version (simulated refinement)
REFINED="[REFINED] Your prompt has been optimized:
- Made instructions more explicit
- Improved structure and readability
- Removed ambiguity
- Added relevant context

Original prompt preserved below for reference:

$PROMPT_CONTENT"

# Output with conversational text AND markdown code block wrapper (this tests the improved stripping functionality)
echo "Here's your refined prompt:"
echo ""
echo '```markdown'
echo "$REFINED"
echo '```'
echo ""
echo "Let me know if you need any further adjustments!"
