/* Sonda schema poll contro una libtdjson via dlopen (td_json_client_execute
 * accetta client NULL per richieste statiche: il parse avviene comunque).
 * Exit 0 se: probe nuovo formato PARSE OK, classico PARSE FAIL, e tutte le
 * varianti nuove (regolare/multi/quiz) PARSE OK. */
#include <stdio.h>
#include <string.h>
#include <dlfcn.h>

static const char *FT = "{\"@type\":\"formattedText\",\"text\":\"x\"}";

static char buf[4096];
static const char *wrap(const char *content)
{
    snprintf(buf, sizeof(buf),
             "{\"@type\":\"sendMessage\",\"chat_id\":1,\"input_message_content\":%s}",
             content);
    return buf;
}

int main(int argc, char **argv)
{
    if (argc < 2) { fprintf(stderr, "uso: %s <libtdjson.so>\n", argv[0]); return 2; }
    void *h = dlopen(argv[1], RTLD_NOW);
    if (!h) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 2; }
    const char *(*exec)(void *, const char *) =
        (const char *(*)(void *, const char *)) dlsym(h, "td_json_client_execute");
    if (!exec) { fprintf(stderr, "dlsym: %s\n", dlerror()); return 2; }

    /* spegni log su stderr */
    exec(NULL, "{\"@type\":\"setLogVerbosityLevel\",\"new_verbosity_level\":0}");

    char content[2048];
    int fail = 0;

    struct { const char *label; const char *json; int expect_ok; } cases[6];
    int n = 0;

    /* probe identica a usesNewPollApi() in tdlibwrapper.cpp */
    snprintf(content, sizeof(content),
        "{\"@type\":\"inputMessagePoll\",\"question\":%s,"
        "\"options\":[{\"@type\":\"inputPollOption\",\"text\":%s}],"
        "\"type\":{\"@type\":\"inputPollTypeRegular\"}}", FT, FT);
    cases[n].label = "probe nuovo formato"; cases[n].json = strdup(wrap(content)); cases[n].expect_ok = 1; n++;

    snprintf(content, sizeof(content),
        "{\"@type\":\"inputMessagePoll\",\"question\":%s,\"options\":[%s,%s],"
        "\"is_anonymous\":true,"
        "\"type\":{\"@type\":\"pollTypeRegular\",\"allow_multiple_answers\":true}}", FT, FT, FT);
    cases[n].label = "formato classico"; cases[n].json = strdup(wrap(content)); cases[n].expect_ok = 0; n++;

    snprintf(content, sizeof(content),
        "{\"@type\":\"inputMessagePoll\",\"question\":%s,"
        "\"options\":[{\"@type\":\"inputPollOption\",\"text\":%s},{\"@type\":\"inputPollOption\",\"text\":%s}],"
        "\"is_anonymous\":true,\"allows_multiple_answers\":false,\"allows_revoting\":true,"
        "\"type\":{\"@type\":\"inputPollTypeRegular\"}}", FT, FT, FT);
    cases[n].label = "nuovo: regolare"; cases[n].json = strdup(wrap(content)); cases[n].expect_ok = 1; n++;

    snprintf(content, sizeof(content),
        "{\"@type\":\"inputMessagePoll\",\"question\":%s,"
        "\"options\":[{\"@type\":\"inputPollOption\",\"text\":%s},{\"@type\":\"inputPollOption\",\"text\":%s}],"
        "\"is_anonymous\":false,\"allows_multiple_answers\":true,\"allows_revoting\":true,"
        "\"type\":{\"@type\":\"inputPollTypeRegular\"}}", FT, FT, FT);
    cases[n].label = "nuovo: multi non-anonimo"; cases[n].json = strdup(wrap(content)); cases[n].expect_ok = 1; n++;

    snprintf(content, sizeof(content),
        "{\"@type\":\"inputMessagePoll\",\"question\":%s,"
        "\"options\":[{\"@type\":\"inputPollOption\",\"text\":%s},{\"@type\":\"inputPollOption\",\"text\":%s}],"
        "\"is_anonymous\":true,\"allows_multiple_answers\":false,"
        "\"type\":{\"@type\":\"inputPollTypeQuiz\",\"correct_option_ids\":[1],\"explanation\":%s}}",
        FT, FT, FT, FT);
    cases[n].label = "nuovo: quiz+spiegazione"; cases[n].json = strdup(wrap(content)); cases[n].expect_ok = 1; n++;

    for (int i = 0; i < n; i++) {
        const char *r = exec(NULL, cases[i].json);
        int ok = r && strstr(r, "synchronously") != NULL;
        printf("%-26s -> %s | %s\n", cases[i].label,
               ok ? "PARSE OK  " : "PARSE FAIL",
               r ? r : "(null)");
        if (ok != cases[i].expect_ok) { fail = 1; }
    }
    printf(fail ? "ESITO: MISMATCH ATTESE\n" : "ESITO: TUTTO COME ATTESO\n");
    return fail;
}
