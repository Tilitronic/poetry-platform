# opencode-v2-migration

Migrate the OpenCode dev-infra runtime from V1 (1.18.32) to V2 (OMO 3.0.7) through a parallel `dev-v2` service with an isolated worktree: delete non-surviving custom mechanisms, port the surviving core to V2 primitives, prove the V2 service, then retire V1.
