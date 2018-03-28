/* ----------------------------------------------------------------------

  ljgidl.c
  Shareable objects for use with RSI/IDL CALL_EXTERNAL

  for Solaris 2.x
  cc -O -G -Kpic -fsingle -c ljgidl.c
  ld -G -o ljgidl.so ljgidl.o

  for SunOS 4.1.x
  acc -c -O -pic ljgidl.c
  ld -assert pure-text -o ljgidl.so ljgidl.o

  --------------------------------------------------------------------- */

#include <ctype.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define DELIMITERS " \t/-:,_;"
#define PDSDELIMITERS " \t/-T:,_;"

#define DATE 0
#define YEAR 1
#define MONTH 2
#define DAY 3
#define HOUR 4
#define MINUTE 5
#define SECOND 6

char *months[] = {"january", "february", "march", "april", "may", "june",
  "july", "august", "september", "october", "november", "december"};

int day_offset[2][14] = {
  {  0,   0,  31,  59,  90, 120, 151, 181, 212, 243, 273, 304, 334, 365},
  {  0,   0,  31,  60,  91, 121, 152, 182, 213, 244, 274, 305, 335, 366} };

int days_in_month[2][14] = {
  { 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0},
  { 0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 0} };

typedef struct {
  unsigned short slen;	/* length of IDL string */
  short stype;		/* type of string:  0=static !0=dynamic */
  char *s;		/* addr of string, invalid if slen == 0 */
} STRING;

int
parsetime (char *string,
           int *year, int *month, int *day_month, int *day_year,
	   int *hour, int *minute, double *second)
{
  char s[80];
  char *c;
  char *delimiters;
  char *end_of_date;
  time_t curtime;
  struct tm *curtm;
  int i, j, len, n;
  char *tok[10];
  int want[7] = {0};
  char *ptr;
  int number;
  double value;
  int hold;
  int leap;

  (void)strncpy (s, string, 80);

  /* handle PDS time format */

  delimiters = DELIMITERS;
  if ((c = strchr (s, 'Z'))) *c = (char)0;
  end_of_date = strchr (s, 'T');
  if (end_of_date) {
    c = end_of_date - 1;
    if (isdigit ((int)(*c))) delimiters = PDSDELIMITERS;
    else end_of_date = (char *)0;
  }

  /* if not PDS then count out 3 non-space delimiters */

  if (!end_of_date) {
    n = 0;
    len = strlen (s);
    for (i = 0; i < len; i++) {
      if ((c = strchr (delimiters+2, (int)s[i]))) n++;
      if (n == 3) {
        end_of_date = s + i;
        break;
      }
    }
  }

  /* default to current year */

  if (time (&curtime) == (time_t)(-1)) return -1;
  if (!(curtm = localtime (&curtime))) return -1;
  *year = curtm->tm_year + 1900;
  *month = 0;
  *day_month = 0;
  *day_year = 0;
  *hour = 0;
  *minute = 0;
  *second = 0.0;

  /* tokenize the time string */

  if (!(tok[0] = strtok (s, delimiters))) return -1;

  for (n = 1; n < 10 && (tok[n] = strtok ((char *)0, delimiters)); n++);

  want[DATE] = want[YEAR] = want[MONTH] = want[DAY] = 1;
  hold = 0;

  for (i = 0; i < n; i++) {

    if (end_of_date && want[DATE] && (tok[i] > end_of_date)) {
      want[DATE] = 0;
      want[HOUR] = want[MINUTE] = want[SECOND] = 1;
    }

    len = strlen (tok[i]);

    value = strtod (tok[i], &ptr);
    if (ptr == tok[i]) {
      if (len < 3 || !want[DATE]) return -1;
      for (c = tok[i]; *c; c++) *c = tolower ((int)(*c));
      for (j = 0; j < 12; j++) {
        if (!strncmp (months[j], tok[i], len)) {
	  *month = j + 1;
	  want[MONTH] = 0;
	  if (hold) {
	    if (*day_month) return -1;
	    *day_month = hold;
	    hold = 0;
	    want[DAY] = 0;
	  }
	  break;
	}
      }
      if (want[MONTH]) return -1;
      continue;
    }

    if (fmod (value, 1.0) != 0.0) {
      if (want[SECOND]) {
        *second = value;
        break;
      } else return -1;
    }

    number = value;
    if (number < 0) return -1;

    if (want[DATE]) {

      if (!number) return -1;

      if (number > 31) {

        if (want[YEAR]) {
	  *year = number;
	  if (*year < 1000) *year += 1900;
	  want[YEAR] = 0;
	} else if (want[MONTH]) {
	  want[MONTH] = 0;
	  *month = 0;
	  *day_year = number;
	  want[DAY] = 0;
	} else return -1;

      } else if (number > 12) {

	if (want[DAY]) {
	  if (hold) {
	    *month = hold;
	    want[MONTH] = 0;
	  }
	  if (len == 3) {
	    if (*month) return -1;
	    *day_year = number;
	    *day_month = 0;
	    want[MONTH] = 0;
	  } else *day_month = number;
	  want[DAY] = 0;
	} else return -1;

      } else if (!want[MONTH]) {

	if (*month) {
	  *day_month = number;
	  *day_year = 0;
	} else {
	  *day_year = number;
	  *day_month = 0;
	}
	want[DAY] = 0;

      } else if (!want[DAY]) {

	if (*day_year) return -1;
	*month = number;
	want[MONTH] = 0;

      } else if (!want[YEAR]) {

	if (len == 3) {
	  if (*month) return -1;
	  *day_year = number;
	  *day_month = 0;
	  want[DAY] = 0;
	} else {
	  if (*day_year) return -1;
	  *month = number;
	  if (hold) {
	    *day_month = hold;
	    want[DAY] = 0;
	  }
	}
	want[MONTH] = 0;

      } else if (hold) {

	*month = hold;
	hold = 0;
	want[MONTH] = 0;
	*day_month = number;
	want[DAY] = 0;

      } else hold = number;

      if (!(want[YEAR] || want[MONTH] || want[DAY])) {
        want[DATE] = 0;
        want[HOUR] = want[MINUTE] = want[SECOND] = 1;
      }

    } else if (want[HOUR]) {

      if (len == 4) {
        hold = number / 100;
	if (hold > 23) return -1;
	*hour = hold;
	hold = number % 100;
	if (hold > 59) return -1;
	*minute = hold;
	want[MINUTE] = 0;
      } else {
        if (number > 23) return -1;
	*hour = number;
      }
      want[HOUR] = 0;

    } else if (want[MINUTE]) {

      if (number > 59) return -1;
      *minute = number;
      want[MINUTE] = 0;

    } else if (want[SECOND]) {

      if (number > 61) return -1;
      *second = number;
      want[SECOND] = 0;

    } else return -1;

  } /* for all tokens */

  if (*month > 12) return -1;
  if (*month && !*day_month) *day_month = 1;

  leap = *year & 3 ? 0 : (*year % 100 ? 1 : (*year % 400 ? 0 : 1));

  if (*month && *day_month && !*day_year) {
    if (*day_month > days_in_month[leap][*month]) return -1;
    *day_year = day_offset[leap][*month] + *day_month;
  } else if (*day_year && !*month && !*day_month) {
    if (*day_year > (365 + leap)) return -1;
    for (i = 2; i < 14 && *day_year > day_offset[leap][i]; i++);
    i--;
    *month = i;
    *day_month = *day_year - day_offset[leap][i];
  } else return -1;

  return 0;

} /* parsetime */

/* ----------------------------------------------------------------------

  call_external ('ljgidl.so', 'str2jdoff', string, jd, off)

  --------------------------------------------------------------------- */

int
str2jdoff (int argc, void *argv[])
{
  STRING *idlstr;
  int *jd;
  double *off;

  int year, month, day_month, day_year, hour, minute;
  double second;

  if (argc < 3) return (0);

  idlstr = argv[0];
  if (!idlstr->slen) return (0);
  jd = argv[1];
  off = argv[2];

  if (parsetime (idlstr->s, &year, &month, &day_month, &day_year,
                 &hour, &minute, &second)) return (0);

  *jd = 367 * year - 7 * (year + (month + 9) / 12) / 4 -
        3 * ((year + (month - 9) / 7) / 100 + 1) / 4 +
	275 * month / 9 + day_month + 1721029;

  *off = second + (double)minute * 60.0 + (double)hour * 3600.0; 

  return (1);

} /* str2jdoff */
