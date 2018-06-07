oc new-project gl-oc-demo-ci-cd --display-name="GL OC Demo CI\CD Infra"
oc new-project gl-oc-demo-ci-cd-dev --display-name="GL OC Demo CI\CD Dev"

oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd

oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd-dev
oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd-dev -n gl-oc-demo-ci-cd-dev

oc adm pod-network join-projects --to=gl-oc-demo-ci-cd gl-oc-demo-ci-cd-dev

mkdir temp

# Deploy Nexus
NEXUS_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/nexus3-template.yaml"

oc process -f $NEXUS_TEMPLATE -n gl-oc-demo-ci-cd > temp/nexus3.yaml 
oc create -f temp/nexus3.yaml -n gl-oc-demo-ci-cd
sleep 5
oc set resources dc/nexus --limits=cpu=1,memory=2Gi --requests=cpu=200m,memory=1Gi -n gl-oc-demo-ci-cd
oc rollout status dc nexus -n gl-oc-demo-ci-cd

# Create Front-End Build(s)
DEV_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/dev-builds-template-front-end.yaml"

oc process -f $DEV_FT_TEMPLATE -n gl-oc-demo-ci-cd-dev > temp/dev-front-end.yaml 
oc create -f temp/dev-front-end.yaml -n gl-oc-demo-ci-cd-dev

read -p "Press enter to continue"