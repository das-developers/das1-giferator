#!/bin/bash
#
# Complete Secure Bash CGI for the data analysis system (das)
# Target Environment: Hybrid Rocky Linux Server Environment
# Relies on the oinkzwurgl.org framework for clean associative array mapping
#

# --- 1. System Headers & Error Page Handling ---

PrintHeader() {
  echo -e "Content-type: text/html\n"
  echo "<HTML>"
  echo "<HEAD><TITLE>das - data analysis system</TITLE></HEAD>"
  echo "<BODY>"
}

PrintTrailer() {
  echo "<HR>"
  echo "<ADDRESS>"
  echo "<A HREF=\"https://space.physics.uiowa.edu/people/Larry_Granroth/\">larry&#45;granroth&#64;uiowa&#46;ed&#117;</A>"
  echo "</ADDRESS>"
  echo "</BODY>"
  echo "</HTML>"
}

PrintErrorExit() {
  local error_msg="$1"
  PrintHeader
  echo "<H2>SECURITY/RUNTIME FAULT: ${error_msg}</H2>"
  echo "<tt>${HTTP_REFERER}</tt>"
  echo "<HR><H3>Contents of log file:</H3><HR><PRE>"
  
  # Safe recovery of file descriptor 2 to avoid logging loops
  exec 2>&3
  
  if [ -r "/planet/tmp/${logfile}" ]; then
    cat "/planet/tmp/${logfile}"
  else
    echo "<EM>Cannot open or view diagnostic log file.</EM>"
  fi
  echo -e "\n</PRE>"
  PrintTrailer
  exit 0
}

# --- 2. CGI Network Ingestion (oinkzwurgl.org Mapping Template) ---

cgi_decode() {
  local sed_script='s/%([0-9a-fA-F][0-9a-fA-F])/\\x\1/g'
  echo -e "$(echo "$1" | sed -E "$sed_script")"
}

declare -A cgi_params
declare -a cgi_param_keys

parse_cgi_input() {
  local input_str=""
  
  if [ "${REQUEST_METHOD}" = "POST" ] && [ "${CONTENT_LENGTH}" -gt 0 ]; then
    read -N "${CONTENT_LENGTH}" input_str
  elif [ "${REQUEST_METHOD}" = "GET" ]; then
    input_str="${QUERY_STRING}"
  fi

  if [ -z "${input_str}" ]; then
    return
  fi

  # Break down incoming input buffers safely on ampersand boundaries
  IFS='&' read -r -a pairs <<< "$input_str"
  for pair in "${pairs[@]}"; do
    local key="${pair%%=*}"
    local val="${pair#*=}"
    
    key="${key//+/ }"
    val="${val//+/ }"
    
    key=$(cgi_decode "$key")
    val=$(cgi_decode "$val")
    
    # Structural Hygiene: Trap raw ampersand smuggling vectors
    if [[ "$key" == *"&"* || "$val" == *"&"* ]]; then
      FATAL_SECURITY_VIOLATION=1
    fi

    # Deduplicate elements while safely maintaining chronological arrival indexes
    if [ -z "${cgi_params[$key]}" ]; then
      cgi_param_keys+=("$key")
      cgi_params[$key]="$val"
    else
      cgi_params[$key]="${cgi_params[$key]}\n$val"
    fi
  done
}

# --- 3. Initial Sandbox Configuration and Stream Hijacking ---

logfile="das.${REMOTE_ADDR}.log"
touch "/planet/tmp/${logfile}" 2>/dev/null
chmod 0666 "/planet/tmp/${logfile}" 2>/dev/null

# Blindly isolate file descriptor 2 to keep stderr artifacts from breaking the HTTP stream
exec 3>&2
exec 2>"/planet/tmp/${logfile}"

FATAL_SECURITY_VIOLATION=0
parse_cgi_input

if [ $FATAL_SECURITY_VIOLATION -eq 1 ]; then
  PrintErrorExit "Malformed parameters containing illegal processing ampersands were detected."
fi

# Define Isolated System Paths
export IDL_DIR="/project/spdr/opt/nv5/idl89"
export PATH="/usr/bin:/bin:/project/spdr/opt/nv5/idl89/bin:/usr/local/bin"

echo -e "CGI shell environment:\nenv\nIDL transactions:" >&2
env >&2

# Establish a secure downstream pipeline to the execution engine
exec 4> >(${IDL_DIR}/bin/idl 2>> "/planet/tmp/${logfile}")
if [ $? -ne 0 ]; then
  PrintHeader
  echo "<H1>ERROR: Could not open pipe to downstream scientific processing core.</H1>"
  PrintTrailer
  exit 0
fi

# Send default compilation and environment directives
cat << EOH >&4
ON_ERROR, 1
CD, '/planet/das/idl8/'
RESTORE, 'gifer.idl'
.RUN giferator.pro
referer = "${HTTP_REFERER}"
logfile = "${logfile}"
EOH

# --- 4. Color Palette Matrices Configurations ---

if [ -n "${cgi_params['gray scale']}" ]; then
  cat << EOH >&4
  gray=interpolate([255,0],(findgen(200)/199.))
  display.color.r=gray
  display.color.g=gray
  display.color.b=gray
EOH
  unset "cgi_params['gray scale']"
elif [ -n "${cgi_params['yarg scale']}" ]; then
  cat << EOH >&4
  gray=interpolate([0,255],(findgen(200)/199.))
  display.color.r=gray
  display.color.g=gray
  display.color.b=gray
EOH
  unset "cgi_params['yarg scale']"
elif [ -n "${cgi_params['fade to white']}" ]; then
  cat << EOH >&4
  display.color.r=interpolate([254,000,000,000,000,255,255,255,255],(findgen(200)+1.)/25.)
  display.color.g=interpolate([255,000,255,255,255,255,200,080,000],(findgen(200)+1.)/25.)
  display.color.b=interpolate([255,255,255,127,000,000,000,000,000],(findgen(200)+1.)/25.)
EOH
  unset "cgi_params['fade to white']"
else
  cat << EOH >&4
  display.color.r=interpolate([000,000,000,000,000,255,255,255,255],(findgen(200)+1.)/25.)
  display.color.g=interpolate([000,000,255,255,255,255,200,080,000],(findgen(200)+1.)/25.)
  display.color.b=interpolate([127,255,255,127,000,000,000,000,000],(findgen(200)+1.)/25.)
  display.color.b(0)=1
EOH
fi

# --- 5. Spacecraft Event Time (SCET) Label Standardization ---

if [[ "${cgi_params['axis(0).x.title']}" == *"SCET"* ]]; then
  begtime="${cgi_params['column(0).tleft']}"
  if [ -n "$begtime" ]; then
    begtime=$(/local/bin/prtime "$begtime" 2>/dev/null)
  fi
  
  endtime="${cgi_params['column(0).tright']}"
  if [ -n "$endtime" ]; then
    endtime=$(/local/bin/prtime "$endtime" 2>/dev/null)
  fi
  
  cgi_params['axis(0).x.title']="'${begtime}    SCET    ${endtime}'"
fi

# --- 6. Rigid Deep Sanitization & Execution Filtering Loop ---

for key in "${cgi_param_keys[@]}"; do
  value="${cgi_params[$key]}"

  # VULNERABILITY GUARD 1: Block Line-Break Injection attempts (\n or \r)
  if [[ "$key" =~ [$'\n'$'\r'] || "$value" =~ [$'\n'$'\r'] ]]; then
    PrintErrorExit "Parameter integrity violation: Injection tokens discovered."
  fi

  # VULNERABILITY GUARD 2: Explicit Structural Whitelisting of Key Patterns
  # Ensures characters fit standard variable arrays or struct patterns: object(index).property
  if [[ ! "$key" =~ ^[a-zA-Z0-9_\.\(\)]+$ ]]; then
    PrintErrorExit "Key name error: Prohibited character sequence used."
  fi

  # VULNERABILITY GUARD 3: Strict Command Blacklisting
  # Intercept common runtime manipulation mechanisms inside assignment values
  normalized_val=$(echo "$value" | tr '[:upper:]' '[:lower:]')
  if [[ "$normalized_val" == *"spawn"* || \
        "$normalized_val" == *"execute"* || \
        "$normalized_val" == *"call_external"* || \
        "$normalized_val" == *"online_help"* ]]; then
    PrintErrorExit "Processing exception: Use of restricted system verbs is denied."
  fi

  # --- 7. Configuration Transmission to NV5 IDL Process ---
  
  if [ "$value" = "init" ]; then
    echo -e "init\n" >&4
  elif [[ "$key" =~ ^[a-zA-Z0-9_]+\([0-9]+\)\.query$ ]]; then
    echo "${key} = ${key} + \"${value}\"" >&4
  elif [[ "$key" =~ \.t(left|right)$ ]] && [[ "$value" =~ ^[^'\"]+.+[^'\"]$ ]]; then
    echo "${key} = '${value}'" >&4
  else
    echo "${key} = ${value}" >&4
  fi
done

# Initiate processing phase and detach system threads
echo -e "go\nexit" >&4
exec 4>&-

# Relinquish stderr channels back to baseline environment
exec 2>&3
exit 0
