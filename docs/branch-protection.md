# Branch Protection Settings

Recommended GitHub branch protection rules for the `main` branch.

## Prerequisites

The CI workflow (`quality` job) must have run on `main` at least once before these settings can be applied.

## Recommended Settings

### Require a pull request before merging
- **ON** - Direct pushes to `main` are blocked
- Require at least 1 approval (optional for solo projects)

### Require status checks to pass before merging
- **ON**
- Required check: `quality`
- Require branches to be up to date before merging

### Allow squash merging only
- **Settings > General > Pull Requests**
- Enable: **Allow squash merging**
- Disable: **Allow merge commits** and **Allow rebase merging**
- Default commit message: **Pull request title**

### Do not allow force pushes
- **ON** - Prevents history rewriting on `main`

### Do not allow deletions
- **ON** - Prevents accidental branch deletion

## How to Apply

1. Push the CI workflow to `main` and confirm it passes
2. Go to **Settings > Branches > Add branch protection rule**
3. Branch name pattern: `main`
4. Enable the settings listed above
5. Click **Create** / **Save changes**
