#include "fzftab.mdh"
#include "fzftab.pro"
#include <sys/stat.h>
#include <unistd.h>
#include <stdlib.h>

const char* get_color(const char *file, const struct stat *sb);
const char* get_suffix(const char *file, const struct stat *sb);
const char* colorize_from_mode(const char *file, const struct stat *sb);
const char* colorize_from_name(const char *file);
int compile_patterns(char *nam, char **list_colors);

/* Indixes into the terminal string arrays. */
#define COL_NO  0
#define COL_FI  1
#define COL_DI  2
#define COL_LN  3
#define COL_PI  4
#define COL_SO  5
#define COL_BD  6
#define COL_CD  7
#define COL_OR  8
#define COL_MI  9
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
static char *colnames[] = {
    "no", "fi", "di", "ln", "pi", "so", "bd", "cd", "or", "mi",
    "su", "sg", "tw", "ow", "st", "ex",
    "lc", "rc", "ec", "tc", "sp", "ma", "hi", "du", "sa", NULL
};

/* Default values. */
static char *defcols[] = {
    "0", "0", "1;31", "1;36", "33", "1;35", "1;33", "1;33", NULL, NULL,
    "37;41", "30;43", "30;42", "34;42", "37;44", "1;32",
    "\033[", "m", NULL, "0", "0", "7", NULL, NULL, "0"
};


struct pattern {
    Patprog pat;
    char color[50];
};

static int pat_cnt = 0;
static struct pattern *name_color = NULL;
static char mode_color[NUM_COLS][20];

static int bin_fzf_tab_compadd(char *nam, char **args, UNUSED(Options ops), UNUSED(int func))
{
    return 0;
}

// TODO: use ZLS_COLORS ?
int compile_patterns(char *nam, char **list_colors)
{
    // clean old name_color and set pat_cnt = 0
    if (pat_cnt != 0) {
        while (--pat_cnt) {
            freepatprog(name_color[pat_cnt].pat);
        }
        free(name_color);
    }
    // initialize mode_color with default value
    for (int i = 0; i < NUM_COLS; i++) {
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
    name_color = zalloc(pat_cnt * sizeof(struct pattern));

    for (int i = 0; i < pat_cnt; i++) {
        char *pat = dupstring(list_colors[i]);
        char *color = strrchr(pat, '=');
        *color = '\0';
        tokenize(pat);
        remnulargs(pat);

        // mode=color
        bool skip = false;
        for (int j = 0; j < NUM_COLS; j++) {
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
        if (!(name_color[i].pat = patcompile(pat, PAT_ZDUP, NULL))) {
            zwarnnam(nam, "bad pattern: %s", list_colors[i]);
            return 1;
        }

        strcpy(name_color[i].color, color + 1);
    }
    return 0;
}

// local -a LIST_COLORS=(xxx)
// colorize -c LIST_COLORS
// colorize file
// echo $reply
static int bin_colorize(char *nam, char **args, Options ops, UNUSED(int func))
{
    char **array, *file;

    if (OPT_ISSET(ops, 'c')) {
        // compile
        if (*args == NULL) {
            zwarnnam(nam, "please specify an array");
            return 1;
        } else {
            array = getaparam(*args);
            return compile_patterns(nam, array);
        }
    } else if (OPT_ISSET(ops, 'v')) {
        printf("0.1.0");
        return 0;
    }

    if ((file = *args) == NULL) {
        zwarnnam(nam, "please specify a file name");
        return 1;
    }

    struct stat sb;
    if (lstat(file, &sb) == -1) {
        zwarnnam(nam, "%s doesn't exists", file);
        return 1;
    }

    const char *suffix = get_suffix(file, &sb);
    const char *color = get_color(file, &sb);

    char symlink[8192] = {0};
    const char *symcolor = "";
    if ((sb.st_mode & S_IFMT) == S_IFLNK) {
        readlink(file, symlink, 8192);
        if (stat(file, &sb) == -1) {
            symcolor = mode_color[COL_OR];
        } else {
            char tmp[PATH_MAX];
            realpath(file, tmp);
            symcolor = get_color(file, &sb);
        }
    }

    if (OPT_ISSET(ops, 'o') ) {
        printf("%s%s%s"
                    "%s"
                    "%s%s%s"
                    "%s",
                    mode_color[COL_LC], color, mode_color[COL_RC], file,
                    mode_color[COL_LC], "0", mode_color[COL_RC], suffix);
        if (symlink[0] != '\0') {
            printf(" -> "
                    "%s%s%s"
                    "%s"
                    "%s%s%s\n",
                    mode_color[COL_LC], symcolor, mode_color[COL_RC], symlink,
                    mode_color[COL_LC], "0", mode_color[COL_RC]);
        }
    } else {
        char **reply = zalloc((4 + 1) * sizeof(char *));
        reply[0] = zalloc(256);
        reply[1] = zalloc(256);
        reply[2] = zalloc(10);
        reply[3] = zalloc(PATH_MAX);
        reply[4] = NULL;
        sprintf(reply[0], "%s%s%s", mode_color[COL_LC], color, mode_color[COL_RC]);
        sprintf(reply[1], "%s%s%s", mode_color[COL_LC], "0", mode_color[COL_RC]);
        sprintf(reply[2], "%s", suffix);
        if (symlink[0] != '\0') {
            sprintf(reply[3], "%s%s%s%s%s%s%s", mode_color[COL_LC], symcolor,
                    mode_color[COL_RC], symlink, mode_color[COL_LC], "0",
                    mode_color[COL_RC]);
        } else {
            reply[3] = ztrdup("");
        }
        setaparam("reply", reply);
    }

    return 0;
}

const char* get_suffix(const char *file, const struct stat *sb)
{
    struct stat sb2;

    switch (sb->st_mode & S_IFMT) {
    case S_IFBLK: return "#";
    case S_IFCHR: return "%";
    case S_IFDIR: return "/";
    case S_IFIFO: return "|";
    case S_IFLNK: {
        if (strpfx(mode_color[COL_LN], "target")) {
            if (stat(file, &sb2) == -1) {
                return "@";
            }
            return get_suffix(file, &sb2);
        } else {
            return "@";
        }
    }
    default: break;
    }

    if (sb->st_mode & S_IXUSR) {
        return "*";
    }

    return "";
}

const char* get_color(const char *file, const struct stat *sb)
{
    // no list-colors, return empty color
    if (pat_cnt == 0) {
        return "";
    }
    const char *ret;
    if ((ret = colorize_from_mode(file, sb)) ||
        (ret = colorize_from_name(file))) {
        return ret;
    }
    return mode_color[COL_FI];
}

const char* colorize_from_name(const char *file)
{
    for (int i = 0; i < pat_cnt; i++) {
        if (name_color[i].pat && pattry(name_color[i].pat, file)) {
            return name_color[i].color;
        }
    }
    return NULL;
}

const char* colorize_from_mode(const char *file, const struct stat *sb)
{
    struct stat sb2;

    switch (sb->st_mode & S_IFMT) {
    case S_IFDIR: return mode_color[COL_DI];
    case S_IFLNK: {
        if (strpfx(mode_color[COL_LN], "target")) {
            if (stat(file, &sb2) == -1 ) {
                return mode_color[COL_OR];
            }
            return get_color(file, &sb2);
        }
    }
    case S_IFIFO: return mode_color[COL_PI];
    case S_IFSOCK: return mode_color[COL_SO];
    case S_IFBLK: return mode_color[COL_BD];
    case S_IFCHR: return mode_color[COL_CD];
    default: break;
    }

    if (sb->st_mode & S_ISUID ) {
        return mode_color[COL_SU];
    } else if (sb->st_mode & S_ISGID) {
        return mode_color[COL_SG];
        // tw ow st ??
    } else if (sb->st_mode & S_IXUSR ) {
        return mode_color[COL_EX];
    }

    /* Check for suffix alias */
    size_t len = strlen(file);
    /* shortest valid suffix format is a.b */
    if (len > 2) {
        const char *suf = file + len - 1;
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

static struct builtin bintab[] = {
    BUILTIN("fzf-tab-colorize", 0, bin_colorize, 0, -1, 0, "cvo", NULL),
    BUILTIN("fzf-tab-compadd", BINF_HANDLES_OPTS, bin_fzf_tab_compadd, 0, -1, 0, NULL, NULL),
};

static struct features module_features = {
    bintab, sizeof(bintab)/sizeof(*bintab),
    0
};

int setup_(UNUSED(Module m))
{
    return 0;
}

int features_(Module m, char ***features)
{
    *features = featuresarray(m, &module_features);
    return 0;
}

int enables_(Module m, int **enables)
{
    return handlefeatures(m, &module_features, enables);
}

int boot_(UNUSED(Module m))
{
    return 0;
}

int cleanup_(UNUSED(Module m))
{
    return 0;
}

int finish_(UNUSED(Module m))
{
    return 0;
}