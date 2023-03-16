#!/usr/bin/env cdrepo
./check_args.sh "$@" || exit 1

function get_completion() {
  curl https://api.openai.com/v1/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $OPENAI_API_KEY" \
    -d "{\"model\": \"text-davinci-003\", \"prompt\": $1, \"temperature\": 0, \"max_tokens\": 1000}" \
    -# | jq -r .choices[0].text
}

function stream_curl() {
  curl https://api.openai.com/v1/completions \
      -H "Content-Type: application/json" \
      -H "Accept: text/event-stream" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "{\"model\": \"text-davinci-003\", \"prompt\": $1, \"temperature\": 0, \"max_tokens\": 1000, \"stream\": true}" \
      -s
}

function get_streaming() {
  stream_curl "$1" | cut -d':' -f2- | while read -r msg; do
    if [ "$msg" != "[DONE]" ]; then
     jq -rj ".choices[0].text" <<< "$msg"
    fi
  done
  echo ""
}

function assign() {
  raw=$(
    echo "Determine whether the listed task should be assigned to Human Secretary or Computer Algorithm."
    echo ""
    echo "Task: Summarize this report."
    echo "Assign to: Human Secretary"
    echo ""
    echo "Task: Compute total profit and loss."
    echo "Assign to: Computer Algorithm"
    echo ""
    echo "Task: $1"
    echo "Assign to:"
  )
  prompt=$(echo "$raw" | jq -sR .)
  get_completion "$prompt"
}

triage=$(assign "$1")
if [ "$triage" = "Computer Algorithm" ]
then
  # allocate temp file
  dir=$(mktemp -d "/tmp/jeannie.XXXXX.XXXXX")
  scratch="$dir/scratch.sh"

  if [ -t 0 ]
  then
    # no stdin
    prompt=$(echo -e "Generate a bash script that performs the listed task\n\nTask: $1\nResult:" | jq -sR .)
    get_completion "$prompt" > "$scratch"
  else
    # with stdin
    prompt=$(echo -e "Generate a bash script that performs the listed transformation on the contents of stdin\n\nTransformation: $1\nResult:" | jq -sR .)
    get_completion "$prompt" > "$scratch"
  fi
  echo "Running script at $scratch..."
  chmod +x "$scratch"
  "$scratch"
else
  if [ -t 0 ]
  then
    # no stdin
    prompt=$(echo -e "Perform the listed task\n\nTask: $1\nResult:" | jq -sR .)
    get_streaming "$prompt"
  else
    # with stdin
    input_txt=$(cat)
    prompt=$(echo -e "Perform a transformation on this input text:\n\n$input_txt\n\nTransformation: $1\nResult:" | jq -sR .)
    get_streaming "$prompt"
  fi
fi

