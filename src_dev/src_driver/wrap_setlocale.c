/* MV202609 workaround for the UCRT setlocale defect (C5)
 *
 * libgfortran's formatted REAL output saves the pointer returned by
 * setlocale(LC_NUMERIC, NULL), calls setlocale(LC_NUMERIC, "C") and then passes
 * the saved pointer back to setlocale. In ucrtbase the second call releases the
 * buffer that the saved pointer refers to, so the restore parses released memory
 * as a locale name; if that memory holds no NUL before the end of the committed
 * heap, the byte scan inside setlocale faults (SIGSEGV). It happens at the first
 * formatted REAL write, rarely and depending on the heap layout, and it is not a
 * defect of TEB-MSU: see docs/TEB_MSU_change_history.md, §5.7 (item C5) and §5.8.
 *
 * This file is compiled and used only with
 *
 *     make -C src WRAP_LOCALE=1
 *
 * which links libgfortran statically and routes its setlocale references to
 * __wrap_setlocale below (the default build is unchanged). For the name == NULL
 * query the wrapper returns a pointer to a permanent buffer, which cannot become
 * dangling; every other call is passed through to the real setlocale unchanged,
 * so the build gives bit-identical results.
 */
#include <locale.h>
#include <string.h>

extern char *__real_setlocale(int category, const char *locale);

char *__wrap_setlocale(int category, const char *locale)
{
    static char saved[256];
    char *r;

    if (locale == NULL)
    {
        r = __real_setlocale(category, NULL);
        if (r == NULL)
            return NULL;
        strncpy(saved, r, sizeof(saved) - 1);
        saved[sizeof(saved) - 1] = '\0';
        return saved;
    }

    return __real_setlocale(category, locale);
}
