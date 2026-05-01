# --- a/doc/nanorc.5 ---
# Insert 'setsyntax' description after wordcount description
/Counts and reports on the status bar the number of lines, words,/ a\
.TP\
.B setsyntax\
Prompts for new syntax highlighting to be applied.

# --- a/src/global.c ---
# 1. Add the setsyntax_gist string
/const char \*suspend_gist = N_("Suspend the editor (return to the shell)");/ a\
	const char *setsyntax_gist = N_("Set new syntax highlighting");

# 2. Add the function to MMAIN
/N_("Word Count"), WHENHELP(wordcount_gist), TOGETHER);/ a\
	add_to_funcs(do_set_syntax, MMAIN,\
		N_("Set Syntax"), WHENHELP(setsyntax_gist), TOGETHER);

# 3. Add the key binding M-5
/add_to_sclist(MMAIN, "M-D", 0, count_lines_words_and_characters, 0);/ a\
	add_to_sclist(MMAIN, "M-5", 0, do_set_syntax, 0);

# --- a/src/prototypes.h ---
# Add the function prototype
/void count_lines_words_and_characters(void);/ a\
void do_set_syntax(void);

# --- a/src/rcfile.c ---
# Add the rcfile command mapping
/else if (!strcmp(input, "wordcount"))/ {
    n
    a\
	else if (!strcmp(input, "setsyntax"))\
		s->func = do_set_syntax;
}

# --- a/src/text.c ---
# Append the do_set_syntax function definition before the verbatim input function
/void do_verbatim_input(void)/ i\
\
/* Prompt user for changing to the new syntax highlighting. We use the spell menu because\
 * it has no functions. */\
void do_set_syntax(void)\
{\
	int response;\
	const char *oldname, *newname;\
	linestruct *line;\
\
	if (openfile->syntax) {\
		response = do_prompt(MSPELL, "", NULL, edit_refresh, "Syntax Name [%s]", openfile->syntax->name);\
	} else {\
		response = do_prompt(MSPELL, "", NULL, edit_refresh, "Syntax Name");\
	}\
	if (response == -1) {\
		statusbar(_("Cancelled"));\
		return;\
	} else if (response == -2) {  // blank input\
		return;\
	}\
\
	syntaxstr = mallocstrcpy(syntaxstr, answer);\
	oldname = openfile->syntax ? openfile->syntax->name : "";\
	find_and_prime_applicable_syntax();\
	newname = openfile->syntax ? openfile->syntax->name : "";\
\
	/* If the syntax changed, discard and recompute the multidata. */\
	if (strcmp(oldname, newname) != 0) {\
		for (line = openfile->filetop; line != NULL; line = line->next) {\
			free(line->multidata);\
			line->multidata = NULL;\
		}\
\
		precalc_multicolorinfo();\
		have_palette = FALSE;\
		refresh_needed = TRUE;\
	}\
}\