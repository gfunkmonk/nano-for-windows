# --- a/doc/nanorc.5 ---
# Add settabsize description to the manual
/and characters in the current buffer (or in the marked region)./ a\
.TP\
.B settabsize\
Prompts for a new tabsize to be set.

# --- a/src/global.c ---
# 1. Add the help string (gist)
/const char \*setsyntax_gist = N_("Set new syntax highlighting");/ a\
	const char *settabsize_gist = N_("Set new tabsize");

# 2. Add the function to the main menu (MMAIN)
/N_("Set Syntax"), WHENHELP(setsyntax_gist), TOGETHER);/ a\
\
	add_to_funcs(do_set_tabsize, MMAIN,\
		N_("Set Tabsize"), WHENHELP(settabsize_gist), TOGETHER);

# 3. Add the M-4 key binding
/add_to_sclist(MMAIN, "M-D", 0, count_lines_words_and_characters, 0);/ a\
	add_to_sclist(MMAIN, "M-4", 0, do_set_tabsize, 0);

# --- a/src/prototypes.h ---
# Insert the function prototype
/void count_lines_words_and_characters(void);/ a\
void do_set_tabsize(void);

# --- a/src/rcfile.c ---
# Map the nanorc string "settabsize" to the function
/else if (!strcmp(input, "wordcount"))/ {
	n
	a\
	else if (!strcmp(input, "settabsize"))\
		s->func = do_set_tabsize;
}

# --- a/src/text.c ---
# Append the function implementation before do_verbatim_input
/void do_verbatim_input(void)/ i\
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
}\