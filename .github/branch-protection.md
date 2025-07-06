# 🛡️ Branch Protection Rules

## Recommended Configuration

Configure the following protection rules for the `main` branch:

### 1. Require a pull request before merging
- ✅ **Enable**
- ✅ **Require approvals**: 1
- ✅ **Dismiss stale PR approvals when new commits are pushed**
- ✅ **Require review from code owners**

### 2. Require status checks to pass before merging
- ✅ **Require branches to be up to date before merging**
- ✅ **Status checks that are required**:
  - `validate` (from pr-check.yml)
  - `security-scan-pr` (from pr-check.yml)
  - `test-pr` (from pr-check.yml)
  - `build-test` (from pr-check.yml)
  - `helm-lint` (from pr-check.yml)

### 3. Require conversation resolution before merging
- ✅ **Enable**

### 4. Require signed commits
- ✅ **Enable**

### 5. Require linear history
- ✅ **Enable**

### 6. Include administrators
- ✅ **Enable**

## How to Configure

1. Go to **Settings** > **Branches**
2. Click **Add rule**
3. Configure the **Branch name pattern**: `main`
4. Apply the configurations above
5. Click **Create**

## CODEOWNERS

Create a `.github/CODEOWNERS` file with:

```
# Global owners
* @mauropimentel

# Backend specific
/backend/ @mauropimentel

# Simulator specific
/simulator/ @mauropimentel

# Infrastructure specific
/infrastructure/ @mauropimentel

# Helm charts
/chart/ @mauropimentel
```

## Benefits

- **Code Quality**: Ensures only reviewed code is merged
- **Security**: Requires security checks before merge
- **Clean History**: Maintains organized git history
- **Compliance**: Meets audit and compliance requirements 