# Importante notes about CRDs

CRDs need to be in their own folder, otherwise clean deployments may fail because some resources need the CRDs. This is a race condition problem.

