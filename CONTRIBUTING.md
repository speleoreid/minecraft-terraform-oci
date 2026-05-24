# Contributing to OCI Free Minecraft Server

Thank you for your interest in contributing! We welcome bug reports, feature requests, documentation improvements, and code contributions.

## How to Contribute

### 1. Reporting Bugs

Found a bug? Open an issue with:

- **Title**: Clear, concise description
- **Description**: What went wrong?
- **Steps to Reproduce**: How to trigger the bug
- **Expected Behavior**: What should happen
- **Actual Behavior**: What actually happened
- **Environment**:
  ```
  - OS: macOS / Linux / Windows
  - Terraform version: (run: terraform --version)
  - OCI Region: us-phoenix-1 / other
  ```
- **Error Output**: Full error messages and logs (redact sensitive info)

### 2. Requesting Features

Have an idea? Open an issue with:

- **Title**: Feature request - [description]
- **Use Case**: Why do you need this?
- **Proposed Solution**: How should it work?
- **Alternatives**: Other solutions you've considered

Examples:
- "Feature request - Auto-scale instance based on player count"
- "Feature request - Add Docker support for Minecraft server"
- "Feature request - Backup to S3 integration"

### 3. Improving Documentation

See a typo or unclear section? Submit a pull request:

1. Fork the repository
2. Create a branch: `git checkout -b docs/fix-typo`
3. Make changes to `.md` files
4. Commit: `git commit -m "docs: fix typo in README"`
5. Push: `git push origin docs/fix-typo`
6. Open pull request

### 4. Code Contributions

Want to improve the Terraform code? Great!

#### Setup

```bash
# Fork repository on GitHub
# Clone your fork
git clone https://github.com/YOUR-USERNAME/oci-minecraft.git
cd oci-minecraft

# Create a branch
git checkout -b feature/my-feature

# Make changes
# ... edit files ...

# Validate Terraform
terraform fmt -recursive .
terraform validate

# Commit with clear messages
git commit -m "feat: add feature X"

# Push and open PR
git push origin feature/my-feature
```

#### Code Standards

- **Terraform Formatting**: Run `terraform fmt -recursive .` before committing
- **Naming Conventions**:
  - Variables: `snake_case` (e.g., `minecraft_data_volume_size_gb`)
  - Resources: `snake_case` (e.g., `oci_core_instance.server_instance`)
  - Outputs: `snake_case` (e.g., `instance0_public_ip`)
- **Comments**: Explain "why", not "what"
  ```hcl
  # GOOD: Prevent accidental destruction of the data volume
  lifecycle {
    prevent_destroy = true
  }

  # BAD: Set lifecycle
  lifecycle {
    prevent_destroy = true
  }
  ```

#### Pull Request Process

1. **Update Documentation**: If adding features, update relevant `.md` files
2. **Test Your Changes**:
   ```bash
   terraform validate
   terraform plan  # Review what would change
   ```
3. **Commit Message**: Use conventional commits
   - `feat: add feature name`
   - `fix: resolve issue X`
   - `docs: update README`
   - `refactor: improve code clarity`
   - `test: add test cases`
4. **PR Description**: Explain what you changed and why
5. **Link Related Issues**: "Fixes #123"

#### Conventional Commits

Use conventional commits in messages:

```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types**:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `refactor`: Code refactor (no feature/fix)
- `perf`: Performance improvement
- `test`: Add/update tests
- `chore`: Build, deps, etc.

**Examples**:
```
feat(compute): add support for custom Java options

This allows users to configure Java heap memory via server properties.
Adds new variable: minecraft_java_opts

Fixes #42
```

---

## Development Guide

### File Structure

```
oci-minecraft/
├── main.tf              # Outputs & data sources
├── network.tf           # VCN, subnets, security
├── compute.tf           # Instance & storage
├── variables.tf         # Variable definitions
├── provider.tf          # OCI provider config
├── user_data.sh         # Instance init script
│
├── README.md            # Main documentation
├── GETTING_STARTED.md   # Setup guide
├── ARCHITECTURE.md      # System design
├── TROUBLESHOOTING.md   # Common issues
├── COST.md              # Pricing info
├── CONTRIBUTING.md      # This file
│
├── terraform.tfvars.example  # Template
├── .gitignore           # Git rules
└── LICENSE              # MIT License
```

### Making Changes

#### Adding a New Input Variable

1. **Define in `variables.tf`**:
   ```hcl
   variable "my_new_variable" {
     type        = string
     description = "What is this for?"
     default     = "default value"
   }
   ```

2. **Use in appropriate `.tf` file**:
   ```hcl
   resource "oci_core_instance" "server_instance" {
     display_name = var.my_new_variable
     ...
   }
   ```

3. **Document in `terraform.tfvars.example`**:
   ```hcl
   # Comment explaining the variable
   my_new_variable = "example value"
   ```

4. **Update `GETTING_STARTED.md`** if user needs to configure it

#### Updating user_data.sh

Be careful! This script:
- Runs on **first instance boot only**
- Cannot be updated on existing instances (requires recreate)
- Is the single point of failure for initialization

**Best Practices**:
- Add error checking: `set -e` and `|| exit 1`
- Use timestamps: `$(date +"%Y-%m-%dT%H:%M:%S %Z")`
- Make idempotent: Should work if run twice
- Test locally first (Bash syntax check):
  ```bash
  bash -n user_data.sh
  ```

#### Adding New Documentation

Create `.md` files with:
- Clear structure with headers
- Code examples for complex topics
- Table of contents for long docs
- Links to related docs

---

## Testing

### Pre-Commit Checklist

Before opening a PR:

```bash
# 1. Format Terraform
terraform fmt -recursive .

# 2. Validate Terraform
terraform validate

# 3. Check for secrets (don't commit terraform.tfvars!)
git status | grep terraform.tfvars

# 4. Review your changes
git diff

# 5. Test plan (dry run)
terraform plan
```

### Manual Testing

If possible, test changes:

```bash
# Initialize
terraform init

# Plan changes
terraform plan -out=tfplan

# Apply (if you have OCI account)
terraform apply tfplan

# Verify on instance
ssh ubuntu@$(terraform output -raw instance0_public_ip)

# Cleanup
terraform destroy
```

---

## Community

- 💬 **Discussions**: Open an issue to discuss ideas
- 🐛 **Bug Reports**: Use GitHub Issues
- 📚 **Documentation**: Update `.md` files directly
- 🌟 **Suggestions**: Let us know how to improve!

---

## Code of Conduct

We are committed to providing a welcoming and inclusive environment:

- Be respectful and constructive
- Welcome diversity of opinions
- Criticize ideas, not people
- Help others learn and grow

---

## License

By contributing, you agree your contributions will be licensed under the MIT License.

---

## Questions?

- Check existing issues (might be answered already)
- Read [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- Open a new issue and ask!

## Thank You!

We appreciate your contributions and efforts to improve OCI Free Minecraft Server! 🎮
