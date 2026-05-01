# 0020-set-tabsize-dynamically.sed
# Convert 0020-set-tabsize-dynamically.patch to sed commands

# doc/nanorc.5 - Add settabsize documentation after wordcount
/\.B wordcount$/,/\.TP$/{
    /\.TP$/a\
.B settabsize\
Prompts for a new tabsize to be set.
}

# src/global.c - Add settabsize_gist constant
/const char \*wordcount_gist =/a\
	const char *settabsize_gist = N_("Set new tabsize");

# src/global.c - Add function registration after count_lines_words_and_characters
/add_to_funcs(count_lines_words_and_characters, MMAIN,$/{
    N
    N
    a\
	add_to_funcs(do_set_tabsize, MMAIN,\
		N_("Set Tabsize"), WHENHELP(settabsize_gist), TOGETHER);
}

# src/global.c - Add keybinding after M-D
/add_to_sclist(MMAIN, "M-D", 0, count_lines_words_and_characters, 0);$/a\
	add_to_sclist(MMAIN, "M-4", 0, do_set_tabsize, 0);

# src/prototypes.h - Add function declaration after count_lines_words_and_characters
/void count_lines_words_and_characters(void);$/a\
void do_set_tabsize(void);

# src/rcfile.c - Add strtosc mapping after wordcount
/else if (!strcmp(input, "wordcount"))$/{
    N
    a\
	else if (!strcmp(input, "settabsize"))\
		s->func = do_set_tabsize;
}

# src/text.c - Add do_set_tabsize function after count_lines_words_and_characters
/^void count_lines_words_and_characters(void)/,/^}$/{
    /^}$/a\
\
/* Prompt user to set the new tabsize. We use the spell menu because\
 * it has no functions. */\
void do_set_tabsize(void)\
{\
	ssize_t new_tabsize = -1;\
	int response = do_prompt(MSPELL, "", NULL, edit_refresh, "New tabsize");\
\
	/* Cancel if no answer provided. */\
	if (response != 0) {\
		statusbar(_("Cancelled"));\
		return;\
	}\
\
	if (!parse_num(answer, &new_tabsize) || new_tabsize <= 0) {\
		statusline(AHEM, _("Requested tab size \"%s\" is invalid"), answer);\
		return;\
	}\
\
	tabsize = new_tabsize;\
	statusline(REMARK, _("Tabsize set to %d"), tabsize);\
}
}
