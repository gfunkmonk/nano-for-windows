# --- a/doc/nano.1 ---
# Insert --nosearchwrap documentation
/Don't show the two help lines/ a\
.TP\
.BR \\-\\-nosearchwrap\
Don't wrap around to the start or end of the buffer when performing search or replace.

# --- a/doc/nanorc.5 ---
# Insert "set nosearchwrap" description
/save non-POSIX text files.)/ a\
.TP\
.B set nosearchwrap\
Don't wrap around to the start or end of the buffer when performing search or replace.

# --- a/src/definitions.h ---
# Add to enum
/ERROR_MESSAGE,/ a\
	NO_SEARCH_WRAP,

# --- a/src/nano.c ---
# 1. Add CLI help text
/print_opt("-x", "--nohelp"/ a\
	print_opt("", "--nosearchwrap", N_("Don't wrap past EOF when search/replace"));

# 2. Add long option to struct
/"magic", 0, NULL, '!'/ a\
		{"nosearchwrap", 0, NULL, '0xCF'},

# 3. Add case handler for hex code
/case 0xCC:/ {
    n
    n
    a\
			case '0xCF':\
				SET(NO_SEARCH_WRAP);\
				break;
}

# --- a/src/rcfile.c ---
# Add rcfile mapping
/{"nonewlines", NO_NEWLINES},/ a\
	{"nosearchwrap", NO_SEARCH_WRAP},

# --- a/src/search.c ---
# Update search logic conditional
s/if (whole_word_only || modus == INREGION)/if (whole_word_only || modus == INREGION || ISSET(NO_SEARCH_WRAP))/

# --- a/syntax/nanorc.nanorc ---
# Update syntax highlighting keywords
s/nohelp|nonewlines/nohelp|nosearchwrap|nonewlines/