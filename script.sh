#!/bin/bash
# This script demonstrates how to integrate the improved backport workflow
# with the leonardo-pinho-legitimuz/teste-carga repository

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Integrating Backport Workflow with teste-carga Repository ===${NC}"

# Step 1: First we need to create a directory structure for the test
WORK_DIR=$(pwd)
TEST_DIR="${WORK_DIR}/backport-test"
mkdir -p "${TEST_DIR}"
cd "${TEST_DIR}"

echo -e "${BLUE}Working directory: ${TEST_DIR}${NC}"

# Step 2: Clone the repository
echo -e "${BLUE}Cloning the repository...${NC}"
git clone https://github.com/leonardo-pinho-legitimuz/teste-carga.git
cd teste-carga

# Step 3: Create branch structure for testing
echo -e "${BLUE}Setting up branch structure...${NC}"

# We need develop and canary branches - since this is just a test repo,
# we'll create these branches and add some content to generate conflicts

# Create develop branch
git checkout -b develop
echo -e "${GREEN}Created develop branch${NC}"

# Create a new file that will have conflicts later
echo '# Configuration File' > config.yaml
echo 'server:' >> config.yaml
echo '  port: 3000' >> config.yaml
echo '  host: localhost' >> config.yaml
echo '  timeout: 5000' >> config.yaml
echo 'database:' >> config.yaml
echo '  host: db.example.com' >> config.yaml
echo '  user: app' >> config.yaml
echo '  password: password123' >> config.yaml

# Add a new custom section to the existing server.log file
cat > server.log << 'EOL'
[2023-12-01] INFO: Application started
[2023-12-01] INFO: Listening on port 3000
[2023-12-01] DEBUG: Configuration loaded from config.yaml
[2023-12-01] INFO: Connected to database
[2023-12-01] INFO: Ready to accept connections
EOL

# Commit the changes to develop
git config user.name "Develop Developer"
git config user.email "develop@example.com"
git add config.yaml server.log
git commit -m "Add configuration file and update logs in develop"

# Create the canary branch from develop
git checkout -b canary
echo -e "${GREEN}Created canary branch from develop${NC}"

# Make changes in the canary branch (different user)
git config user.name "Canary Developer"
git config user.email "canary@example.com"

# Modify the config.yaml file with conflicting changes
echo '# Configuration File' > config.yaml
echo 'server:' >> config.yaml
echo '  port: 8080' >> config.yaml
echo '  host: 0.0.0.0' >> config.yaml
echo '  timeout: 10000' >> config.yaml
echo '  max_connections: 100' >> config.yaml
echo 'database:' >> config.yaml
echo '  host: db.example.com' >> config.yaml
echo '  user: admin' >> config.yaml
echo '  password: securePassword456' >> config.yaml
echo 'cache:' >> config.yaml
echo '  enabled: true' >> config.yaml
echo '  ttl: 3600' >> config.yaml

# Modify the server.log file with different content
cat > server.log << 'EOL'
[2023-12-15] INFO: Application started on 0.0.0.0:8080
[2023-12-15] INFO: Running in production mode
[2023-12-15] DEBUG: Memory usage: 512MB
[2023-12-15] INFO: Database connection established
[2023-12-15] INFO: Cache initialized
[2023-12-15] INFO: Ready to accept connections
EOL

# Create a new file that won't have conflicts
echo 'This is a performance monitoring log' > performance.log
echo '[2023-12-15] CPU: 15%' >> performance.log
echo '[2023-12-15] Memory: 30%' >> performance.log
echo '[2023-12-15] Disk: 45%' >> performance.log
echo '[2023-12-15] Network: 10%' >> performance.log

# Commit the changes to canary
git add config.yaml server.log performance.log
git commit -m "Update configuration and logs in canary"

echo -e "${GREEN}Created conflicting changes between develop and canary branches${NC}"

# Step 4: Implement the key conflict detection logic from our GitHub workflow
# Create a file that contains the core logic from our improved workflow

cat > backport_test.sh << 'EOL'
#!/bin/bash
# Key conflict detection logic from the improved GitHub workflow

# Define output colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Testing backport conflict detection...${NC}"

# Step 1: Try to merge from canary to develop
git checkout develop
echo -e "${BLUE}Attempting to merge canary into develop...${NC}"

if git merge canary; then
    echo -e "${GREEN}Merge succeeded without conflicts${NC}"
    git reset --hard HEAD~1  # Undo the merge for testing purposes
    exit 0
else
    echo -e "${YELLOW}Merge conflicts detected${NC}"

    # Get the list of conflicting files
    CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
    echo -e "${BLUE}Conflicting files:${NC}"
    echo "$CONFLICT_FILES"

    # Initialize contributor tracking
    declare -A CONTRIBUTORS_SCORE
    declare -A CONTRIBUTORS_EMAIL
    declare -A CONTRIBUTORS_TYPE
    declare -A CONTRIBUTORS_BRANCHES

    # Step 2: Analyze each conflicting file
    for FILE in $CONFLICT_FILES; do
        echo -e "\n${YELLOW}Analyzing conflicts in ${FILE}${NC}"

        # Check for conflict markers
        CONFLICT_MARKERS=$(grep -n "^<<<<<<< HEAD" "$FILE" || echo "")

        if [ -n "$CONFLICT_MARKERS" ]; then
            echo -e "${BLUE}Found conflict markers:${NC}"

            # Process each conflict block
            while IFS= read -r LINE; do
                if [[ $LINE =~ ^([0-9]+):.* ]]; then
                    # Found start of conflict at this line number
                    START_LINE="${BASH_REMATCH[1]}"

                    # Find the separator line (=======)
                    SEPARATOR_LINE=$(tail -n +$START_LINE "$FILE" | grep -n "^=======" | head -1)
                    if [[ $SEPARATOR_LINE =~ ^([0-9]+):.* ]]; then
                        SEPARATOR_LINE_NUM=$((START_LINE + ${BASH_REMATCH[1]} - 1))

                        # Find the end line (>>>>>>>)
                        END_LINE=$(tail -n +$SEPARATOR_LINE_NUM "$FILE" | grep -n "^>>>>>>>" | head -1)
                        if [[ $END_LINE =~ ^([0-9]+):.* ]]; then
                            END_LINE_NUM=$((SEPARATOR_LINE_NUM + ${BASH_REMATCH[1]} - 1))

                            echo -e "${BLUE}Conflict block at lines ${START_LINE}-${END_LINE_NUM}${NC}"

                            # Extract the conflicting content for analysis
                            DEVELOP_LINES=$((START_LINE + 1))
                            DEVELOP_LINES_END=$((SEPARATOR_LINE_NUM - 1))
                            CANARY_LINES=$((SEPARATOR_LINE_NUM + 1))
                            CANARY_LINES_END=$((END_LINE_NUM - 1))

                            echo -e "${BLUE}Develop version (lines ${DEVELOP_LINES}-${DEVELOP_LINES_END}):${NC}"
                            sed -n "${DEVELOP_LINES},${DEVELOP_LINES_END}p" "$FILE" | sed 's/^/    /'

                            echo -e "${BLUE}Canary version (lines ${CANARY_LINES}-${CANARY_LINES_END}):${NC}"
                            sed -n "${CANARY_LINES},${CANARY_LINES_END}p" "$FILE" | sed 's/^/    /'

                            # Step 3: Find who edited these specific lines in each branch
                            echo -e "${YELLOW}Finding who edited these lines in develop...${NC}"

                            # Save current state and checkout develop to check blame
                            git merge --abort
                            git checkout develop

                            # Get original line numbers in develop (before the merge conflict)
                            DEVELOP_AUTHOR=""
                            git blame -L 1,100 "$FILE" > develop_blame.txt
                            DEVELOP_BLAME_COUNT=$(wc -l < develop_blame.txt)

                            if [ $DEVELOP_BLAME_COUNT -gt 0 ]; then
                                DEVELOP_AUTHOR=$(grep -m 1 "^.*(" develop_blame.txt | sed 's/.*(\(.*\) .*/\1/')
                                DEVELOP_EMAIL=$(git log -1 --format='%ae' --author="$DEVELOP_AUTHOR")

                                echo -e "${BLUE}Develop lines edited by:${NC} $DEVELOP_AUTHOR <$DEVELOP_EMAIL>"

                                # Add to our tracking
                                CONTRIBUTORS_SCORE["$DEVELOP_AUTHOR"]=1
                                CONTRIBUTORS_EMAIL["$DEVELOP_AUTHOR"]="$DEVELOP_EMAIL"
                                CONTRIBUTORS_BRANCHES["$DEVELOP_AUTHOR"]="develop "
                            else
                                echo "Could not determine who edited develop version"
                            fi

                            # Now check canary branch
                            echo -e "${YELLOW}Finding who edited these lines in canary...${NC}"
                            git checkout canary

                            # Get original line numbers in canary
                            CANARY_AUTHOR=""
                            git blame -L 1,100 "$FILE" > canary_blame.txt
                            CANARY_BLAME_COUNT=$(wc -l < canary_blame.txt)

                            if [ $CANARY_BLAME_COUNT -gt 0 ]; then
                                CANARY_AUTHOR=$(grep -m 1 "^.*(" canary_blame.txt | sed 's/.*(\(.*\) .*/\1/')
                                CANARY_EMAIL=$(git log -1 --format='%ae' --author="$CANARY_AUTHOR")

                                echo -e "${BLUE}Canary lines edited by:${NC} $CANARY_AUTHOR <$CANARY_EMAIL>"

                                # Add to our tracking
                                if [[ -v CONTRIBUTORS_SCORE["$CANARY_AUTHOR"] ]]; then
                                    CONTRIBUTORS_SCORE["$CANARY_AUTHOR"]=$((CONTRIBUTORS_SCORE["$CANARY_AUTHOR"] + 1))

                                    # Check if they edited both branches
                                    if [[ "${CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]}" == *"develop"* ]]; then
                                        CONTRIBUTORS_TYPE["$CANARY_AUTHOR"]="high_priority"
                                    fi

                                    # Add canary branch if not already there
                                    if [[ ! "${CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]}" == *"canary"* ]]; then
                                        CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]+="canary "
                                    fi
                                else
                                    CONTRIBUTORS_SCORE["$CANARY_AUTHOR"]=1
                                    CONTRIBUTORS_EMAIL["$CANARY_AUTHOR"]="$CANARY_EMAIL"
                                    CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]="canary "
                                fi
                            else
                                echo "Could not determine who edited canary version"
                            fi

                            # Clean up
                            rm -f develop_blame.txt canary_blame.txt
                        fi
                    fi
                fi
            done <<< "$CONFLICT_MARKERS"
        else
            echo "No explicit conflict markers found. Using diff-based analysis."

            # Perform diff-based analysis between the branches for this file
            git checkout develop
            DEVELOP_TEMP=$(mktemp)
            git show develop:"$FILE" > "$DEVELOP_TEMP" 2>/dev/null

            git checkout canary
            CANARY_TEMP=$(mktemp)
            git show canary:"$FILE" > "$CANARY_TEMP" 2>/dev/null

            # Find differences
            DIFF_OUTPUT=$(diff -u "$DEVELOP_TEMP" "$CANARY_TEMP")
            DIFF_LINE_COUNT=$(echo "$DIFF_OUTPUT" | grep -E "^[-+]" | grep -v "^---" | grep -v "^+++" | wc -l)

            echo "Found $DIFF_LINE_COUNT differing lines between the branches"

            # Get the last person to edit this file in each branch
            git checkout develop
            DEVELOP_AUTHOR=$(git log -1 --format='%an' -- "$FILE")
            DEVELOP_EMAIL=$(git log -1 --format='%ae' -- "$FILE")

            echo -e "${BLUE}File last edited in develop by:${NC} $DEVELOP_AUTHOR <$DEVELOP_EMAIL>"

            git checkout canary
            CANARY_AUTHOR=$(git log -1 --format='%an' -- "$FILE")
            CANARY_EMAIL=$(git log -1 --format='%ae' -- "$FILE")

            echo -e "${BLUE}File last edited in canary by:${NC} $CANARY_AUTHOR <$CANARY_EMAIL>"

            # Add to tracking
            CONTRIBUTORS_SCORE["$DEVELOP_AUTHOR"]=1
            CONTRIBUTORS_EMAIL["$DEVELOP_AUTHOR"]="$DEVELOP_EMAIL"
            CONTRIBUTORS_BRANCHES["$DEVELOP_AUTHOR"]="develop "

            if [[ -v CONTRIBUTORS_SCORE["$CANARY_AUTHOR"] ]]; then
                CONTRIBUTORS_SCORE["$CANARY_AUTHOR"]=$((CONTRIBUTORS_SCORE["$CANARY_AUTHOR"] + 1))

                # Check if they edited both branches
                if [[ "${CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]}" == *"develop"* ]]; then
                    CONTRIBUTORS_TYPE["$CANARY_AUTHOR"]="high_priority"
                fi

                # Add canary branch if not already there
                if [[ ! "${CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]}" == *"canary"* ]]; then
                    CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]+="canary "
                fi
            else
                CONTRIBUTORS_SCORE["$CANARY_AUTHOR"]=1
                CONTRIBUTORS_EMAIL["$CANARY_AUTHOR"]="$CANARY_EMAIL"
                CONTRIBUTORS_BRANCHES["$CANARY_AUTHOR"]="canary "
            fi

            # Clean up
            rm -f "$DEVELOP_TEMP" "$CANARY_TEMP"
        fi
    done

    # Step 4: Create summary of contributors
    echo -e "\n${BLUE}=== Potential Contributors for Conflict Resolution ===${NC}"
    echo -e "The following contributors have last edited the conflicting lines:"
    echo -e "----------------------------------------------------------"

    # Create GitHub PR-style output
    GITHUB_USERS=""
    for author in "${!CONTRIBUTORS_SCORE[@]}"; do
        score=${CONTRIBUTORS_SCORE["$author"]}
        email=${CONTRIBUTORS_EMAIL["$author"]}
        branches=${CONTRIBUTORS_BRANCHES["$author"]}

        # Extract username for GitHub mention
        if [[ "$email" == *"@"* ]]; then
            username=$(echo "$email" | cut -d@ -f1)
            GITHUB_HANDLE="@$username"
        else
            GITHUB_HANDLE="@unknown"
        fi

        # Format based on priority
        if [[ "${CONTRIBUTORS_TYPE["$author"]}" == "high_priority" ]]; then
            echo -e "${YELLOW}HIGH PRIORITY:${NC} $author <$email> ($GITHUB_HANDLE) - Last edited conflicting lines in $branches - Score: $score"
            GITHUB_USERS+="$GITHUB_HANDLE "
        else
            echo -e "$author <$email> ($GITHUB_HANDLE) - Last edited conflicting lines in $branches - Score: $score"
            GITHUB_USERS+="$GITHUB_HANDLE "
        fi