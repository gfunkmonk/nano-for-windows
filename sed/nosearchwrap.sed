# 0019-no-search-wrap.sed
# Convert 0019-no-search-wrap.patch to sed commands

# doc/nano.1 - Add --nosearchwrap option after -x
/\.BR \-x ", " \-\-nohelp$/,/Don't show the two help lines/{
    /Don't show the two help lines/i\
.TP\
.BR \-\-nosearchwrap\
Don't wrap around to the start or end of the buffer when performing search or replace.
}

# doc/nanorc.5 - Add set nosearchwrap after nonewlines
/\.B set nonewlines$/,/Don't automatically add a newline/{
    /Don't automatically add a newline/i\
.TP\
.B set nosearchwrap\
Don't wrap around to the start or end of the buffer when performing search or replace.
}

# src/definitions.h - Add NO_SEARCH_WRAP flag after ERROR_MESSAGE
/ERROR_MESSAGE,$/a\
	NO_SEARCH_WRAP,

# src/nano.c - Add print_opt after wrap_at assignment
/wrap_at = fill;$/{
    N
    /#endif$/a\
	print_opt("", "--nosearchwrap", N_("Don't wrap past EOF when search/replace"));
}

# src/nano.c - Add long option in options array
/#ifdef HAVE_LIBMAGIC$/,/{"magic", 0, NULL, '!'},$/{
    /{"magic", 0, NULL, '!'},$/a\
		{"nosearchwrap", 0, NULL, '\x01'},
}

# src/nano.c - Add case handler for '\x01' after 0xCC
/case 0xCC:$/,/SET(WHITESPACE_DISPLAY);$/{
    /SET(WHITESPACE_DISPLAY);$/a\
			case '\x01':\
				SET(NO_SEARCH_WRAP);\
				break;
}

# src/rcfile.c - Add nosearchwrap option after nonewlines
/{"nonewlines", NO_NEWLINES},$/a\
	{"nosearchwrap", NO_SEARCH_WRAP},

# src/search.c - Modify wrap condition to include NO_SEARCH_WRAP
/if (whole_word_only || modus == INREGION) {$/s/if (whole_word_only || modus == INREGION) {/if (whole_word_only || modus == INREGION || ISSET(NO_SEARCH_WRAP)) {/

# syntax/nanorc.nanorc - Add nosearchwrap to the set/unset regex
/afterends|allow_insecure_backup/s/afterends|allow_insecure_backup/afterends|allow_insecure_backup|nosearchwrap/
/nohelp|nonewlines/s/nohelp|nonewlines/nohelp|nosearchwrap|nonewlines/
