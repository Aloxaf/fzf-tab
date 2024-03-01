#include "fzftab.mdh"
#include "fzftab.pro"
#include <stdarg.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

const char* get_color(char* file, const struct stat* sb);
const char* colorize_from_mode(char* file, const struct stat* sb);
const char* colorize_from_name(char* file);
int compile_patterns(char* nam, char** list_colors);
char* ftb_strcat(char* dst, int n, ...);

/* Indixes into the terminal string arrays. */
#define COL_NO 0
#define COL_FI 1
#define COL_DI 2
#define COL_LN 3
#define COL_PI 4
#define COL_SO 5
#define COL_BD 6
#define COL_CD 7
#define COL_OR 8
#define COL_MI 9
#define COL_SU 10
#define COL_SG 11
#define COL_TW 12
#define COL_OW 13
#define COL_ST 14
#define COL_EX 15
#define COL_LC 16
#define COL_RC 17
#define COL_EC 18
#define COL_TC 19
#define COL_SP 20
#define COL_MA 21
#define COL_HI 22
#define COL_DU 23
#define COL_SA 24

#define NUM_COLS 25

/* Names of the terminal strings. */
static char* colnames[] = { "no", "fi", "di", "ln", "pi", "so", "bd", "cd", "or", "mi", "su", "sg",
    "tw", "ow", "st", "ex", "lc", "rc", "ec", "tc", "sp", "ma", "hi", "du", "sa", NULL };

/* Default values. */
static char* defcols[]
    = { "0", "0", "1;31", "1;36", "33", "1;35", "1;33", "1;33", NULL, NULL, "37;41", "30;43",
          "30;42", "34;42", "37;44", "1;32", "\033[", "m", NULL, "0", "0", "7", NULL, NULL, "0" };

static char* fzf_tab_module_version;

struct pattern {
    Patprog pat;
    char color[50];
};

static int opt_list_type = OPT_INVALID;
static int pat_cnt = 0;
static struct pattern* name_color = NULL;
static char mode_color[NUM_COLS][20];

// TODO: use ZLS_COLORS ?
int compile_patterns(char* nam, char** list_colors)
{
    int i, j;
    // clean old name_color and set pat_cnt = 0
    if (pat_cnt != 0) {
        while (--pat_cnt) {
            freepatprog(name_color[pat_cnt].pat);
        }
        free(name_color);
    }
    // initialize mode_color with default value
    for (i = 0; i < NUM_COLS; i++) {
        if (defcols[i]) {
            strcpy(mode_color[i], defcols[i]);
        }
    }
    // empty array, just return
    if (list_colors == NULL) {
        return 0;
    }

    // how many pattens?
    while (list_colors[pat_cnt] != NULL) {
        pat_cnt++;
    }
    name_color = zshcalloc(pat_cnt * sizeof(struct pattern));

    for (i = 0; i < pat_cnt; i++) {
        char* pat = ztrdup(list_colors[i]);
        char* color = strrchr(pat, '=');
        if (color == NULL)
            continue;
        *color = '\0';
        tokenize(pat);
        remnulargs(pat);

        // mode=color
        bool skip = false;
        for (j = 0; j < NUM_COLS; j++) {
            if (strpfx(colnames[j], list_colors[i])) {
                strcpy(mode_color[j], color + 1);
                name_color[i].pat = NULL;
                skip = true;
            }
        }
        if (skip) {
            continue;
        }

        // name=color
        if ((name_color[i].pat = patcompile(pat, PAT_ZDUP, NULL))) {
            strcpy(name_color[i].color, color + 1);
        }

        free(pat);
    }
    return 0;
}

static char get_suffix(char* file, const struct stat* sb)
{
    struct stat sb2;
    mode_t filemode = sb->st_mode;

    if (S_ISLNK(filemode))
        if (strpfx(mode_color[COL_LN], "target")) {
            if (stat(file, &sb2) == -1) {
                return '@';
            }
            return get_suffix(file, &sb2);
        } else {
            return '@';
        }
    else
        return file_type(filemode);
}

const char* get_color(char* file, const struct stat* sb)
{
    // no list-colors, return NULL
    if (pat_cnt == 0) {
        return NULL;
    }
    const char* ret;
    if ((ret = colorize_from_mode(file, sb)) || (ret = colorize_from_name(file))) {
        return ret;
    }
    return mode_color[COL_FI];
}

const char* colorize_from_name(char* file)
{
    int i;
    for (i = 0; i < pat_cnt; i++) {
        if (name_color && name_color[i].pat && pattry(name_color[i].pat, file)) {
            return name_color[i].color;
        }
    }
    return NULL;
}

const char* colorize_from_mode(char* file, const struct stat* sb)
{
    struct stat sb2;

    switch (sb->st_mode & S_IFMT) {
    case S_IFDIR:
        return mode_color[COL_DI];
    case S_IFLNK: {
        if (strpfx(mode_color[COL_LN], "target")) {
            if (stat(file, &sb2) == -1) {
                return mode_color[COL_OR];
            }
            return get_color(file, &sb2);
        }
    }
    case S_IFIFO:
        return mode_color[COL_PI];
    case S_IFSOCK:
        return mode_color[COL_SO];
    case S_IFBLK:
        return mode_color[COL_BD];
    case S_IFCHR:
        return mode_color[COL_CD];
    default:
        break;
    }

    if (sb->st_mode & S_ISUID) {
        return mode_color[COL_SU];
    } else if (sb->st_mode & S_ISGID) {
        return mode_color[COL_SG];
        // tw ow st ??
    } else if (sb->st_mode & S_IXUSR) {
        return mode_color[COL_EX];
    }

    /* Check for suffix alias */
    size_t len = strlen(file);
    /* shortest valid suffix format is a.b */
    if (len > 2) {
        const char* suf = file + len - 1;
        while (suf > file + 1) {
            if (suf[-1] == '.') {
                if (sufaliastab->getnode(sufaliastab, suf)) {
                    return mode_color[COL_SA];
                }
                break;
            }
            suf--;
        }
    }

    return NULL;
}

struct {
    char** array;
    size_t len;
    size_t size;
} ftb_compcap;

// Usage:
// initialize               fzf-tab-generate-compcap -i
// output to _ftb_compcap   fzf-tab-generate-compcap -o
// add a entry              fzf-tab-generate-compcap word desc opts
static int bin_fzf_tab_compcap_generate(char* nam, char** args, Options ops, UNUSED(int func))
{
    int i;

    if (OPT_ISSET(ops, 'o')) {
        // write final result to _ftb_compcap
        setaparam("_ftb_compcap", ftb_compcap.array);
        ftb_compcap.array = NULL;
        return 0;
    } else if (OPT_ISSET(ops, 'i')) {
        // init
        if (ftb_compcap.array)
            freearray(ftb_compcap.array);
        ftb_compcap.array = zshcalloc(1024 * sizeof(char*));
        ftb_compcap.len = 0, ftb_compcap.size = 1024;
        return 0;
    }
    if (ftb_compcap.array == NULL) {
        zwarnnam(nam, "please initialize it first");
        return 1;
    }

    // get paramaters
    char **words = getaparam(args[0]), **dscrs = getaparam(args[1]), *opts = getsparam(args[2]);
    if (!words || !dscrs || !opts) {
        zwarnnam(nam, "wrong argument");
        return 1;
    }

    char *bs = metafy("\2", 1, META_DUP), *nul = metafy("\0word\0", 6, META_DUP);
    size_t dscrs_cnt = arrlen(dscrs);

    for (i = 0; words[i]; i++) {
        // TODO: replace '\n'
        char* dscr = i < dscrs_cnt ? dscrs[i] : words[i];
        char *buffer = ftb_strcat(NULL, 5, dscr, bs, opts, nul, words[i]);
        ftb_compcap.array[ftb_compcap.len++] = buffer;

        if (ftb_compcap.len == ftb_compcap.size) {
            ftb_compcap.array
                = zrealloc(ftb_compcap.array, (1024 + ftb_compcap.size) * sizeof(char*));
            ftb_compcap.size += 1024;
            memset(ftb_compcap.array + ftb_compcap.size - 1024, 0, 1024 * sizeof(char*));
        }
    }

    zsfree(bs);
    zsfree(nul);

    return 0;
}

// cat n string, return the pointer to the new string
// dst will be reallocated if is not big enough
// if dst is NULL, it will be allocated
char* ftb_strcat(char* dst, int n, ...)
{
    int i, idx;

    va_list valist;
    va_start(valist, n);

    char* final = dst ? zrealloc(dst, 128) : zalloc(128);
    size_t size = 128, max_len = 128 - 1;
    dst = final;

    for (i = 0, idx = 0; i < n; i++) {
        char* src = va_arg(valist, char*);
        if (src == NULL)
            continue;
        for (; *src != '\0'; dst++, src++, idx++) {
            if (idx == max_len) {
                size += size / 2;
                final = zrealloc(final, size);
                max_len = size - 1;
                dst = &final[idx];
            }
            *dst = *src;
        }
    }
    *dst = '\0';
    va_end(valist);

    return final;
}

struct file_color {
    char *fc_begin;
    char *fc_end;
    char *sc;
    char *suffix;
};

// accept an
static struct file_color* fzf_tab_colorize(char* file)
{
    struct file_color *fc = zalloc(sizeof(struct file_color));

    file = unmeta(file);

    struct stat sb;
    if (lstat(file, &sb) == -1) {
        return NULL;
    }

    char suffix[2] = {0};
    if (isset(opt_list_type)) {
        suffix[0] = get_suffix(file, &sb);
    }
    const char* color = get_color(file, &sb);

    char* symlink = NULL;
    const char* symcolor = "";
    if ((sb.st_mode & S_IFMT) == S_IFLNK) {
        symlink = zshcalloc(PATH_MAX);
        size_t end = readlink(file, symlink, PATH_MAX);
        symlink[end] = '\0';
        if (stat(file, &sb) == -1) {
            symcolor = mode_color[COL_OR];
        } else {
            char tmp[PATH_MAX];
            realpath(file, tmp);
            symcolor = get_color(file, &sb);
        }
    }

    if (color != NULL) {
        fc->fc_begin = ftb_strcat(NULL, 3, mode_color[COL_LC], color, mode_color[COL_RC]);
        fc->fc_end = ftb_strcat(NULL, 3, mode_color[COL_LC], "0", mode_color[COL_RC]);
    } else {
        fc->fc_begin = ztrdup("");
        fc->fc_end = ztrdup("");
    }

    fc->suffix = ztrdup(suffix);

    if (symlink != NULL) {
        fc->sc = ftb_strcat(NULL, 7, mode_color[COL_LC], symcolor, mode_color[COL_RC],
                              symlink, mode_color[COL_LC], "0", mode_color[COL_RC]);
        free(symlink);
    } else {
        fc->sc = ztrdup("");
    }

    fc->fc_begin = metafy(fc->fc_begin, -1, META_REALLOC);
    fc->fc_end = metafy(fc->fc_end, -1, META_REALLOC);
    fc->sc = metafy(fc->sc, -1, META_REALLOC);
    fc->suffix = metafy(fc->suffix, -1, META_REALLOC);

    return fc;
}

static int bin_fzf_tab_candidates_generate(char* nam, char** args, Options ops, UNUSED(int func))
{
    int i, j;

    if (OPT_ISSET(ops, 'i')) {
        // compile list_colors pattern
        if (*args == NULL) {
            zwarnnam(nam, "please specify an array");
            return 1;
        } else {
            char** array = getaparam(*args);
            return compile_patterns(nam, array);
        }
    }

    char **ftb_compcap = getaparam("_ftb_compcap"), **group_colors = getaparam("group_colors"),
         *default_color = getsparam("default_color"), *prefix = getsparam("prefix");

    size_t group_colors_len = arrlen(group_colors);
    size_t ftb_compcap_len = arrlen(ftb_compcap);

    char *bs = metafy("\b", 1, META_DUP), *nul = metafy("\0", 1, META_DUP),
         *soh = metafy("\2", 1, META_DUP);

    char **candidates = zshcalloc(sizeof(char*) * (ftb_compcap_len + 1)),
         *filepath = zshcalloc(PATH_MAX * sizeof(char)), *dpre = zshcalloc(128),
         *dsuf = zshcalloc(128);

    char* first_word = NULL;
    int same_word = 1;

    for (i = 0; i < ftb_compcap_len; i++) {
        char *word = "", *group = NULL, *realdir = NULL;
        strcpy(dpre, "");
        strcpy(dsuf, "");

        // extract all the variables what we need
        char** compcap = sepsplit(ftb_compcap[i], soh, 1, 0);
        char* desc = compcap[0];
        char** info = sepsplit(compcap[1], nul, 1, 0);

        for (j = 0; info[j]; j += 2) {
            if (!strcmp(info[j], "word")) {
                word = info[j + 1];
                // unquote word
                parse_subst_string(word);
                remnulargs(word);
                untokenize(word);
            } else if (!strcmp(info[j], "group")) {
                group = info[j + 1];
            } else if (!strcmp(info[j], "realdir")) {
                realdir = info[j + 1];
            }
        }

        // check if all the words are the same
        if (first_word == NULL) {
            first_word = ztrdup(word);
        } else if (same_word && strcmp(word, first_word) != 0) {
            same_word = 0;
        }

        // add character and color to describe the type of the files
        if (realdir) {
            filepath = ftb_strcat(filepath, 2, realdir, word);
            struct file_color *fc = fzf_tab_colorize(filepath);
            if (fc != NULL) {
                dpre = ftb_strcat(dpre, 2, fc->fc_end, fc->fc_begin);
                if (fc->sc[0] != '\0') {
                    dsuf = ftb_strcat(dsuf, 4, fc->fc_end, fc->suffix, " -> ", fc->sc);
                } else {
                    dsuf = ftb_strcat(dsuf, 2, fc->fc_end, fc->suffix);
                }
                if (dpre[0] != '\0') {
                    setiparam("colorful", 1);
                }
                free(fc);
            }
        }

        char* result = zshcalloc(256 * sizeof(char));

        // add color to description if they have group index
        if (group) {
            // use strtol ?
            int group_index = atoi(group);
            char* color = group_index >= group_colors_len ? "" : group_colors[group_index - 1];
            // add prefix
            result = ftb_strcat(
                result, 11, group, bs, color, prefix, dpre, nul, group, bs, desc, nul, dsuf);
        } else {
            result = ftb_strcat(result, 6, default_color, dpre, nul, desc, nul, dsuf);
        }
        // quotedzputs(result, stdout);
        // putchar('\n');
        candidates[i] = result;

        freearray(info);
        freearray(compcap);
    }

    setaparam("tcandidates", candidates);
    setiparam("same_word", same_word);
    zsfree(dpre);
    zsfree(dsuf);
    zsfree(filepath);
    zsfree(first_word);

    return 0;
}

static struct builtin bintab[] = {
    BUILTIN("fzf-tab-compcap-generate", 0, bin_fzf_tab_compcap_generate, 0, -1, 0, "io", NULL),
    BUILTIN("fzf-tab-candidates-generate", 0, bin_fzf_tab_candidates_generate, 0, -1, 0, "i", NULL),
};

static struct paramdef patab[] = {
    STRPARAMDEF("FZF_TAB_MODULE_VERSION", &fzf_tab_module_version),
};

// clang-format off
static struct features module_features = {
    bintab, sizeof(bintab) / sizeof(*bintab),
    NULL, 0,
    NULL, 0,
    patab, sizeof(patab) / sizeof(*patab),
    0,
};
// clang-format on

int setup_(UNUSED(Module m)) { return 0; }

int features_(Module m, char*** features)
{
    *features = featuresarray(m, &module_features);
    return 0;
}

int enables_(Module m, int** enables) { return handlefeatures(m, &module_features, enables); }

int boot_(UNUSED(Module m))
{
    fzf_tab_module_version = ztrdup("0.2.2");
    // different zsh version may have different value of list_type's index
    // so query it dynamically
    opt_list_type = optlookup("list_types");
    return 0;
}

int cleanup_(UNUSED(Module m)) { return setfeatureenables(m, &module_features, NULL); }

int finish_(UNUSED(Module m))
{
    printf("fzf-tab module unloaded.\n");
    fflush(stdout);
    return 0;
}
