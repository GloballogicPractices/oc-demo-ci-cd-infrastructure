oc new-project gl-demo-ci-cd --display-name="GL Demo CI\CD Infra"
oc new-project gl-demo-ci-cd-dev --display-name="GL Demo CI\CD Dev"

oc adm policy add-role-to-group admin system:serviceaccounts:gl-demo-ci-cd -n gl-demo-ci-cd

oc adm policy add-role-to-group admin system:serviceaccounts:gl-demo-ci-cd -n gl-demo-ci-cd-dev
oc adm policy add-role-to-group admin system:serviceaccounts:gl-demo-ci-cd-dev -n gl-demo-ci-cd-dev

oc adm pod-network join-projects --to=gl-demo-ci-cd gl-demo-ci-cd-dev

read -p "Press enter to continue"