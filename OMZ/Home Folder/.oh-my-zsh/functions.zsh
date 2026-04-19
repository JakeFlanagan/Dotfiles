## ls rewrite
unalias ll 2>/dev/null
ll() {

  if ! command -v gawk &>/dev/null; then
    echo "ll: gawk is required but not installed."
    echo "    Debian/Ubuntu:  apt install gawk"
    echo "    RPM-based:      dnf install gawk"
    echo "    Arch:           pacman -S gawk"
    echo "    Alpine:         apk add gawk"
    return 1
  fi

  local current_user
  current_user=$(whoami)

  ls -l \
    --color=never \
    --time-style='+(%a %-d %b - %H:%M)' \
    --dereference \
    --indicator-style=slash \
    --literal \
    --human-readable \
    --group-directories-first \
    --author \
    "$@" | awk -v cu="$current_user" '
  BEGIN {
    RESET  = "\033[0m"
    BLUE   = "\033[1;34m"
    CYAN   = "\033[0;36m"
    GREEN  = "\033[1;32m"
    WHITE  = "\033[0;37m"
    YELLOW = "\033[1;33m"
    GREY   = "\033[0;90m"
    ORANGE = "\033[38;5;208m"
    RED    = "\033[0;31m"
    BOLD   = "\033[1;37m"
    w_name   = length("File/Folder")
    w_size   = length("Size")
    w_author = length("Author")
    w_date   = length("Date")
    w_owner  = 0
    w_group  = 0
    w_perms  = 0
  }
  function perm2oct(p,    oct, i, bits) {
    oct = ""
    for (i = 1; i <= 3; i++) {
      bits = 0
      if (substr(p, (i-1)*3+2, 1) != "-") bits += 4
      if (substr(p, (i-1)*3+3, 1) != "-") bits += 2
      if (substr(p, (i-1)*3+4, 1) ~ /[xsStT]/) bits += 1
      oct = oct bits
    }
    return oct
  }
  function user_color(u) {
    if (u == "root") return RED
    if (u != cu)     return ORANGE
    return GREY
  }
  function fmt_date(d,    parts) {
    split(d, parts, " ")
    return parts[1] " " sprintf("%2s", parts[2]) " " parts[3] " " parts[4] " " parts[5]
  }
  function make_sep(n,    s, i) {
    s = ""; for (i=0; i<n; i++) s = s "_"
    return s
  }
  NR==1 { h=$0; next }
  {
    perms=$1; owner=$3; group=$4; author=$5; size=$6
    date=$7" "$8" "$9" "$10" "$11
    name=""; for(i=12;i<=NF;i++) name=(name==""?$i:name" "$i)

    rows[NR][1]=perms; rows[NR][2]=owner; rows[NR][3]=group
    rows[NR][4]=author; rows[NR][5]=size; rows[NR][6]=date; rows[NR][7]=name

    if (length(name)   > w_name)   w_name   = length(name)
    if (length(size)   > w_size)   w_size   = length(size)
    if (length(author) > w_author) w_author = length(author)
    if (length(date)   > w_date)   w_date   = length(date)
    if (length(owner)  > w_owner)  w_owner  = length(owner)
    if (length(group)  > w_group)  w_group  = length(group)
    if (length(perms)  > w_perms)  w_perms  = length(perms)
  }
  END {
    printf "\n"
    full_w = w_name + 2 + w_size + 2 + w_author + 2 + w_date + 2 \
           + w_owner + w_group + 19 + 2 \
           + w_perms + 8
    sep = make_sep(full_w)

    # Header
    printf "%s%-*s  %*s  %-*s  %-*s%s\n",
      BOLD,
      w_name,   "File/Folder",
      w_size,   "Size",
      w_author, "Author",
      w_date,   "Date",
      RESET

    # Header separator
    printf "%s%s%s\n", GREY, sep, RESET

    item_count = 0
    for (r=2; r<=NR; r++) {
      perms=rows[r][1]; owner=rows[r][2]; group=rows[r][3]
      author=rows[r][4]; size=rows[r][5]; date=rows[r][6]; name=rows[r][7]

      type=substr(perms,1,1)
      if      (type=="d")          nc=BLUE
      else if (type=="l")          nc=CYAN
      else if (index(perms,"x")>1) nc=GREEN
      else                         nc=WHITE

      oct  = perm2oct(perms)
      fd   = fmt_date(date)
      oc   = user_color(owner)
      gc   = user_color(group)

      og_str = GREY "[Owner: " oc sprintf("%-*s", w_owner, owner) GREY " / Group: " gc sprintf("%-*s", w_group, group) GREY "]" RESET
      p_str  = GREY "[" oct " / " sprintf("%-*s", w_perms, perms) "]" RESET

      printf "%s%-*s%s  %s%*s%s  %s%-*s%s  %s%-*s%s  %s  %s\n",
        nc,     w_name,   name,   RESET,
        YELLOW, w_size,   size,   RESET,
        WHITE,  w_author, author, RESET,
        CYAN,   w_date,   fd,     RESET,
        og_str, p_str

      item_count++
    }

    #printf "%s%s%s\n", GREY, sep, RESET
    printf "\n"
    printf "%sTotal Item Count: %d%s\n", GREY, item_count, RESET
    printf "\n"
  }
  '
}
