# 0018-syntax-on-the-fly.sed
# Convert 0018-syntax-on-the-fly.patch to sed commands

# doc/nanorc.5 - Add setsyntax documentation after wordcount
/\.B wordcount$/,/\.TP$/{
    /\.TP$/a\
.B setsyntax\
Prompts for new syntax highlighting to be applied.
}

# src/global.c - Add setsyntax_gist constant
/const char \*wordcount_gist =/a\
	const char *setsyntax_gist = N_("Set new syntax highlighting");

# src/global.c - Add function registration after count_lines_words_and_characters
/add_to_funcs(count_lines_words_and_characters, MMAIN,$/{
    N
    N
    a\
	add_to_funcs(do_set_syntax, MMAIN,\
		N_("Set Syntax"), WHENHELP(setsyntax_gist), TOGETHER);
}

# src/global.c - Add keybinding after M-D
/add_to_sclist(MMAIN, "M-D", 0, count_lines_words_and_characters, 0);$/a\
	add_to_sclist(MMAIN, "M-5", 0, do_set_syntax, 0);

# src/prototypes.h - Add function declaration after count_lines_words_and_characters
/void count_lines_words_and_characters(void);$/a\
void do_set_syntax(void);

# src/rcfile.c - Add strtosc mapping after wordcount
/else if (!strcmp(input, "wordcount"))$/{
    N
    a\
	else if (!strcmp(input, "setsyntax"))\
		s->func = do_set_syntax;
}

# src/text.c - Add do_set_syntax function after count_lines_words_and_characters
/^void count_lines_words_and_characters(void)/,/^}$/{
    /^}$/a\
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
}
}