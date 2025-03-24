#!/bin/bash
set -e

# Function to print colored messages
print_message() {
  local color="$1"
  local message="$2"
  case "$color" in
    "green") echo -e "\033[0;32m$message\033[0m" ;;
    "red") echo -e "\033[0;31m$message\033[0m" ;;
    "yellow") echo -e "\033[0;33m$message\033[0m" ;;
    *) echo "$message" ;;
  esac
}

# Configure git pull strategy
git config pull.rebase false

# Test the backport workflow by simulating changes and conflicts
print_message "yellow" "Starting backport test"

# Create a common file in develop branch
git checkout develop
git pull origin develop --no-rebase || git pull origin develop --ff-only || true
echo "# Common file for testing conflicts" > conflict-test.txt
echo "Line 1: This line will be edited in both branches" >> conflict-test.txt
echo "Line 2: This line will remain the same" >> conflict-test.txt
echo "Line 3: This line will also be edited in both branches" >> conflict-test.txt
git add conflict-test.txt
git commit -m "Add common file for conflict testing"
git push origin develop

# Make changes in canary branch
git checkout canary
# Use merge strategy explicitly to avoid the divergent branches error
git pull origin develop --no-rebase
echo "# Common file for testing conflicts" > conflict-test.txt
echo "Line 1: This line was edited in canary branch by $(git config user.name)" >> conflict-test.txt
echo "Line 2: This line will remain the same" >> conflict-test.txt
echo "Line 3: Canary branch edit by $(git config user.name)" >> conflict-test.txt
echo "Line 4: Added in canary branch" >> conflict-test.txt
git add conflict-test.txt
git commit -m "Update conflict-test.txt in canary"
git push origin canary

# Create a PR for the canary branch changes
if [ "$GH_INSTALLED" = true ]; then
  print_message "yellow" "Creating a test PR on canary branch..."
  PR_URL=$(gh pr create --base canary --head canary --title "Test PR for backport" --body "This is a test PR to verify the backport workflow" || echo "PR_CREATE_FAILED")

  if [ "$PR_URL" != "PR_CREATE_FAILED" ]; then
    print_message "green" "Created test PR: $PR_URL"
    PR_NUMBER=$(echo $PR_URL | grep -oE '[0-9]+$')

    # Merge the PR
    print_message "yellow" "Merging the test PR..."
    gh pr merge $PR_NUMBER --merge --delete-branch || print_message "red" "Failed to merge the PR automatically"
  else
    print_message "yellow" "Failed to create a PR with gh CLI. You will need to create and merge a PR manually to test."
    print_message "yellow" "1. Go to your repository on GitHub"
    print_message "yellow" "2. Create a new PR from canary to canary (this is just for testing)"
    print_message "yellow" "3. Merge the PR"
  fi
else
  print_message "yellow" "GitHub CLI not available. Please create a test PR manually:"
  print_message "yellow" "1. Go to your repository on GitHub"
  print_message "yellow" "2. Create a new PR from canary to canary (this is just for testing)"
  print_message "yellow" "3. Merge the PR"
fi

# Make conflicting changes in develop branch
git checkout develop
git pull origin develop --no-rebase || git pull origin develop --ff-only || true
echo "# Common file for testing conflicts" > conflict-test.txt
echo "Line 1: This line was edited in develop branch by $(git config user.name)" >> conflict-test.txt
echo "Line 2: This line will remain the same" >> conflict-test.txt
echo "Line 3: Develop branch edit by $(git config user.name)" >> conflict-test.txt
git add conflict-test.txt
git commit -m "Update conflict-test.txt in develop"
git push origin develop

# Copy workflow files to canary branch
git checkout canary
git pull origin canary --no-rebase || git pull origin canary --ff-only || true
mkdir -p .github/workflows
cp .github/workflows/auto-backport-canary.yml .github/workflows/
cp .github/workflows/conflict-notification.yml .github/workflows/
git add .github/workflows/auto-backport-canary.yml .github/workflows/conflict-notification.yml
git commit -m "Add auto-backport and conflict notification workflows"
git push origin canary

print_message "green" "Test setup complete."
print_message "green" "The GitHub Actions workflow should run when you create and merge a PR to the canary branch."
print_message "green" "After the PR is merged, check your repository for the backport PR to develop branch."

if [ "$GH_INSTALLED" = false ]; then
  print_message "yellow" "Since GitHub CLI is not installed, you need to manually create a PR for testing:"
  print_message "yellow" "1. Go to your repository on GitHub"
  print_message "yellow" "2. Create a new PR from canary to canary"
  print_message "yellow" "3. Add a unique change to test backporting"
  print_message "yellow" "4. After merging, the backport action should trigger automatically"
fi

print_message "green" "To manually trigger a backport, you can run the workflow from GitHub Actions tab"
print_message "green" "and specify a PR number to backport."
