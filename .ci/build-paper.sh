#!/bin/bash -x
#set -e

# Are there changes in the tex directory?
if git diff --name-only $TRAVIS_COMMIT_RANGE | grep 'tex/'
then

    # Install texlive
    sudo apt-get -qq update && sudo apt-get install -y --no-install-recommends texlive-full

    # Generate the figures
    echo "Generating figures..."
    cd $TRAVIS_BUILD_DIR/tex/figures
    for f in *.py; do
        echo "Running $f..."
        python "$f"
    done

    # Build the paper
    cd $TRAVIS_BUILD_DIR/tex
	pdflatex -interaction=nonstopmode -halt-on-error limbdark.tex
	bibtex limbdark
	pdflatex -interaction=nonstopmode -halt-on-error limbdark.tex
	pdflatex -interaction=nonstopmode -halt-on-error limbdark.tex
    pdflatex -interaction=nonstopmode -halt-on-error limbdark.tex

    # Force push the paper to GitHub
    cd $TRAVIS_BUILD_DIR
    git checkout --orphan $TRAVIS_BRANCH-pdf
    git rm -rf .ci
    git rm -rf tests
    git rm -rf LICENSE
    git rm -rf README.md
    git rm -rf .gitignore
    git rm -rf .travis.yml
    git rm -rf tex/figures
    # todo: more
    git add -f tex/limbdark.pdf
    git -c user.name='travis' -c user.email='travis' commit -m "building the paper"
    git push -q -f https://$GITHUB_USER:$GITHUB_API_KEY@github.com/$TRAVIS_REPO_SLUG $TRAVIS_BRANCH-pdf

fi