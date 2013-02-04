#!/bin/sh
#
# This hook prevents you from committing any file containing debug code.
# e.g. dsm(), dpm(), alert() and console.log(). There is also a PHP LINT check
# to ensure your syntax is okay.
#
# To enable this hook, symlink it (run this from the root of the repository).
#
# ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
#
# To force a commit that breaks the below rules (e.g. when debug code is 100%
# required you can add in another parameter to `git commit` namely `--no-verify`.
#
# Helpful git aliases for these are:
# git config --global alias.gc commit
# git config --global alias.gcv commit --no-verify

# Non-zero exit aborts the commit
ABORT_COMMIT=1

DIFF_FILES=$(git diff-index HEAD --cached --name-only)

if [ $? -ne 0 ]; then
  echo "Error getting list of changed files in pre-commit hook"
  exit $ABORT_COMMIT
fi

# Assume success.
EXIT=0

# n.b. pwd is always the working copy's root directory.
STAGED=".validate_pre_commit"
mkdir -p "$STAGED"
# Truncate the LINT error log file
LINTLOG="$STAGED/lint.log"
>$LINTLOG

# Note that we have to checkout the staged version of each file, so that
# we are actually testing what is going to be committed!
#
# Otherwise (if we tested against the working copy) we could have syntax
# errors in the staged version with inadvertantly-unstaged fixes, and we
# wouldn't catch the problem.

# PHP code checks.
PHP_FILES="\.(php|module|install|inc)$"
for FILE in ${DIFF_FILES}
do
  PARSEABLE=$(echo "$FILE" | grep -E "$PHP_FILES");
  if [ "$PARSEABLE" != "" ]; then
    git checkout-index -f --prefix=$STAGED/ "$FILE"

    # Calls to debug functions should not be committed.
    # print_r() has valid uses with its optional $return argument,
    # so we do not test for it.
    # n.b. This regexp needs to be valid for both egrep & PHP's preg_match()
    PATTERN='\b(var_dump|dpq|dpm|dvm|dsm|dpr|kpr|dvr|kprint_r|dprint_r|devel_render|ddebug_backtrace|debug_backtrace|debug_print_backtrace)\('
    # By initially matching against code which has been stripped of
    # comments, we can reliably eliminate any files which include only
    # commented calls to debug functions.
    php -r "exit(preg_match('/$PATTERN/', php_strip_whitespace('$STAGED/$FILE')));"
    if [ $? -ne 0 ]; then
      # The output of php_strip_whitespace() is of no use for display
      # purposes, so we still need to grep the files; but we can at least
      # eliminate any //-style comments from the code before looking for
      # the matches.
      cat "$STAGED/$FILE" | sed 's|//.*||' | egrep -in -C2 "$PATTERN"
      echo "---------------------------------------"
      echo "^ Found PHP debug code in $FILE"
      echo "---------------------------------------"
      EXIT=$ABORT_COMMIT # but still run the remaining tests
    fi

    # PHP LINT syntax checks.
    php -l "$STAGED/$FILE" >>$LINTLOG 2>&1
    ERRORS=$?
    if [ $ERRORS -eq 255 ]; then
      ERROR_FILES="$ERROR_FILES $FILE"
    fi

    rm -f "$STAGED/$FILE"
  fi
done

# Javascript code checks.
# Calls to the following functions should not be committed:
# alert, console.log.
for FILE in ${DIFF_FILES}
do
  PARSEABLE=$(echo "$FILE" | grep -E "\.(js|coffee)$");
  if [ "$PARSEABLE" != "" ]; then
    git checkout-index -f --prefix=$STAGED/ "$FILE"

    # Calls to debug functions should not be committed.
    PATTERN="\b(console\.log|alert)\("
    # As with the PHP tests, we can strip comments from the code before
    # grepping for the function calls, to avoid displaying false-positives.
    cat "$STAGED/$FILE" | sed 's|//.*||' | egrep -in -C2 "$PATTERN"
    if [ $? -eq 0 ]; then
      echo "---------------------------------------"
      echo "^ Found Javascript debug code in $FILE"
      echo "---------------------------------------"
      EXIT=$ABORT_COMMIT # but still run the remaining tests
    fi

    rm -f "$STAGED/$FILE"
  fi
done

# Report PHP LINT results.
if [ "$ERROR_FILES" != "" ]; then
  echo "\nThe following syntax errors were found:"
  echo "---------------------------------------"
  IGNORE="^(Errors parsing|No syntax errors detected)"
  cat $LINTLOG | egrep -v "$IGNORE" | sed "s|$STAGED/||"
  echo "---------------------------------------"
  EXIT=$ABORT_COMMIT # but still run the remaining tests
fi

if [ $EXIT -ne 0 ]; then
  echo "\nCan't commit; fix errors first."
  echo "(If you definitely need to commit this as-is, use the --no-verify option.)"
  echo "\nIf the reported line numbers do not match, try stashing your unstaged changes:"
  echo "git stash save --keep-index\n"
fi

# Clean up the directory, if preferred:
# rm -f $LINTLOG
# find $STAGED -type d -print0 | xargs -0r rmdir -p --ignore-fail-on-non-empty

exit $EXIT
