# Important Guidelines For Developers:
* Don't ever try to change anything in production branch. It is the default branch; once changed, very difficult to revert back.
* Don't ever Commit a Buggy Code.
* The Development branch arising from production is the main branch; you have to create your respective feature branches from Development branch only.
* You can not directly merge your respective feature branch to the development or production branches, create a pull request to merge those changes.
* Everyday follow this, pull -> develop -> commit on local -> push to remote

  
# Branch Naming Conventions:
featureName [Description]
subfeatureName [Description]

# Commit Naming Convention:
Commit messages should be descriptive such as:
if you added a feature then write "[Added]:- Description"
if you fixed a bug then write " [Fixed]:- Description"
if you updated a feature then write "[Updated]:- Description"

# App Description:
