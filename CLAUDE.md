# Claude Code Task Completion Rules

## Task Completion Definition
A task is considered complete ONLY when ALL of the following criteria are met:

### 1. Code Quality Requirements
- [ ] No linter errors (`dart analyze` returns exit code 0)
- [ ] No compiler errors
- [ ] No warnings (unless explicitly acceptable)
- [ ] Code follows project conventions and style

### 2. Testing Requirements  
- [ ] Write tests for new functionality
- [ ] All existing tests continue to pass
- [ ] New tests achieve reasonable coverage
- [ ] Integration tests pass if applicable

### 3. Validation Commands
Run these commands to validate completion:

```bash
# Linting and analysis
dart analyze

# Run all tests
dart test

# Check test coverage (if configured)
dart test --coverage

# Format code (if needed)
dart format .
```

### 4. Documentation Requirements
- [ ] Public APIs have documentation comments
- [ ] Complex logic has inline comments
- [ ] Update relevant documentation files if needed

### 5. Integration Requirements
- [ ] Changes integrate properly with existing codebase
- [ ] No breaking changes without explicit approval
- [ ] Dependencies are properly managed

## Failure Conditions
Mark a task as incomplete if ANY of these occur:
- Linter errors remain
- Tests fail
- Code doesn't compile
- Breaking changes introduced
- Security vulnerabilities introduced

## Quality Gates
Before marking any task as complete:
1. Run `dart analyze` - must return clean
2. Run `dart test` - all tests must pass
3. Verify functionality works as expected
4. Confirm no regressions introduced

## Emergency Procedures  
If blocked by:
- **Test failures**: Fix failing tests or revert changes
- **Linter errors**: Address all linting issues
- **Dependencies**: Resolve dependency conflicts
- **Integration issues**: Ensure compatibility with existing code

Never mark a task complete with known issues remaining.