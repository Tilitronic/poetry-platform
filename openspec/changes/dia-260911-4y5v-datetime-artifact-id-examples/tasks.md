## 1. Normalize instruction examples

- [x] 1.1 Correct the four confirmed instruction surfaces so concrete artifact
      examples use allocated datetime IDs, both destinations use the returned ID
      verbatim, and generic naming templates remain. Blockers: none. Acceptance:
      lane guidance is internally consistent, and the DIA ticket ID and canonical
      filename are unchanged.

## 2. Verify the narrow correction

- [x] 2.1 Run the focused obsolete-example search against only the four scoped
      instruction surfaces, then run `make test-config`. Blockers: 1.1. Acceptance:
      no obsolete `ana<NN>` or `res<NN>` examples remain in scope, and the config
      gate passes.
