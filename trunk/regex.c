/** <module> Prolog binding to regex.

This is a simple binding to the standard UNIX regular expressions library.

@author Ian Haywood
@license GPL
*/

#include <regex.h>
#include <SWI-Prolog.h>
#include <string.h>

static PL_blob_t blob; /* our blob type */

static foreign_t regex_err(int code);


/** Compile the regular expression to a atom BLOB 
regex: unified to opaque regular expression object
str: string defining regular expression
opts: atom containing letters for regex flags
  x = use POSIX extended regular expressions
  i = ignore case
  s = don't bother with subexpressions
  m = multiline strings
  
will throw exception if can't compile, of the form regex_error(string,number)
*/
static foreign_t
pl_regcomp(term_t regex, term_t str, term_t opts)
{ char *a;
  char *o;
  int n,eflags;
  regex_t *reg;
  
  reg = malloc(sizeof(regex_t));
  eflags = 0;
  if ( PL_get_atom_chars(str, &a) )
  { 
    if (PL_get_atom_chars(opts,&o) )
    {
      while (*o != '\0')
      {
        switch(*o)
        {
        case 'x':
          eflags = eflags|REG_EXTENDED;
          break;
        case 'i':
          eflags = eflags|REG_ICASE;
          break;
        case 'm':
          eflags = eflags|REG_NEWLINE;
          break;
        case 's':
          eflags = eflags|REG_NOSUB;
          break;
        }
        o++;
      }
      n = regcomp(reg,a,eflags);
      if (n == 0)
      {
        PL_unify_blob(regex,reg,sizeof(regex_t),&blob);
        PL_succeed;
      }
      else
        return regex_err(n);
    }
  }
  PL_fail;
}


/** Worker function for finding regular expressions, not called directly 
Deterministic, fails if not found
reg_t: the compiled regexp
str: the string to search as an atom
matches_t: a Prolog list of variables to put in the subexpression matches
start: offset into the string to search from
finish: offset of end of found expression, NULL if not required
*/
static foreign_t 
pl_regexec_work(term_t reg_t, term_t str, term_t matches_t, int start, int *finish)
{
  char *a;
  regex_t *reg;
  regmatch_t *matches;
  int nmatches = 0;
  term_t head = PL_new_term_ref();      /* variable for the elements */
  term_t list = PL_copy_term_ref(matches_t);    /* copy as we need to write */
  int i = 0;
  
  if (PL_get_atom_chars(str, &a))
  {
    if (PL_get_blob(reg_t,(void **)&reg,NULL,NULL))
      {
        while( PL_get_tail(list, list) )
          nmatches++;
        if (nmatches>0)
          matches = malloc(nmatches*sizeof(regmatch_t));
        if (regexec(reg,a+start,nmatches,matches,0) == 0)
        {
          list = PL_copy_term_ref(matches_t);
          while(PL_get_list(list,head,list))
          {
            if (matches[i].rm_so>-1)
              PL_unify_chars(head,PL_ATOM|REP_UTF8,matches[i].rm_eo-matches[i].rm_so,a+matches[i].rm_so+start);
            i++;
          }
          if (nmatches>0)
          {
            if (finish)
              *finish = matches[0].rm_eo+start;
            free(matches);
          }
          PL_succeed;
        }
        else
          if (nmatches>0)
            free(matches);
      }
  }
  PL_fail;
}

/** Simple deterministic match */
static foreign_t 
pl_regexec(term_t reg_t, term_t str, term_t matches_t)
{
  return pl_regexec_work(reg_t,str,matches_t,0,NULL);
}


/** search, returns a solution for each occurence of the regex in the string */
static foreign_t
pl_regfind(term_t reg_t, term_t str, term_t matches_t, control_t handle)
{
  int finish;
  
  switch( PL_foreign_control(handle) )
  { case PL_FIRST_CALL:
    case PL_REDO:
        if (pl_regexec_work (reg_t,str,matches_t,PL_foreign_context(handle),&finish))
          PL_retry(finish);
        else
          PL_fail;
    case PL_CUTTED:
        PL_succeed;
  }
}

/** C layer requires cleanup, should be called by prolog garage collector as required */
static int
pl_regfree (atom_t myblob)
{
  regex_t *reg;
  size_t len;
  PL_blob_t *type;
  
  reg = PL_blob_data(myblob,&len,&type);
  regfree(reg);
  return TRUE;
}

install_t
install()
{ 
  memset(&blob,0,sizeof(PL_blob_t));
  blob.magic = PL_BLOB_MAGIC;
  blob.name = "regex";
  blob.release = &pl_regfree;
  PL_register_foreign("regcomp", 3, pl_regcomp, 0);
  PL_register_foreign("regexec", 3, pl_regexec, 0);
  PL_register_foreign("regfind",3,pl_regfind,PL_FA_NONDETERMINISTIC);
}

install_t
uninstall ()
{
  PL_unregister_blob_type (&blob);
}


static foreign_t regex_err(int code)
{
  char *a;
  term_t except;
  
  switch (code)
  {
  case REG_BADBR:
    a = "Invalid use of back reference operator";
    break;
  case REG_BADPAT:
    a = "Invalid use of pattern operators such as group or list";
    break;
  case REG_BADRPT:
    a = "Invalid use of repetition operators such as using * as the first character";
    break;
  case REG_EBRACE:
    a = "Un-matched brace interval operators";
    break;
  case REG_EBRACK:
    a = "Un-matched bracket list operators.";
    break;
  case REG_ECOLLATE:
    a = "Invalid collating element.";
    break;
  case REG_ECTYPE:
    a = "Unknown character class name.";
    break;
  case REG_EEND:
    a = "Non specific error.";
    break;
  case REG_EESCAPE:
    a= "Trailing backslash.";
    break;
  case REG_EPAREN:
    a = "Un-matched parenthesis group operators.";
    break;
  case REG_ERANGE:
    a = "Invalid use of the range operator, eg. the ending point of the range occurs prior to the starting point.";
    break;
  case REG_ESIZE:
    a = "Compiled regular expression requires a pattern buffer larger than 64Kb.  This is not defined by POSIX.2.";
    break;
  case REG_ESPACE:
    a = "The regex routines ran out of memory.";
    break;
  case REG_ESUBREG:
    a = "Invalid back reference to a subexpression.";
  }
  except = PL_new_term_ref();
  PL_unify_term(except,
    PL_FUNCTOR_CHARS, "regex_error", 2,
    PL_CHARS, a,
    PL_INT, code);
  return PL_raise_exception(except);
}
