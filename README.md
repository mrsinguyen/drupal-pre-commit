Drupal Pre Commit
=================

A Drupal pre-commit hook to help write better code.

## Installation

```
cd /tmp
git clone https://github.com/mrsinguyen/drupal-pre-commit.git
cd drupal-pre-commit
cp scripts/pre-commit.sh [PATH_TO_YOUR_DRUPAL_PROJECT]/scripts
cd [PATH_TO_YOUR_DRUPAL_PROJECT]
ln -s ../../scripts/pre-commit.sh .git/hooks/pre-commit
```

Thanks for original develop by Sean
