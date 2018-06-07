function add_npm_proxy() {
  local _REPO_ID=$1
  local _NEXUS_USER=$2
  local _NEXUS_PWD=$3
  local _NEXUS_URL=$4

  read -r -d '' _REPO_JSON << EOM
{
  "name": "$_REPO_ID",
  "type": "groovy",
  "content": "repository.createNpmProxy('$_REPO_ID',' https://registry.npmjs.org/')"
}
EOM

  curl -v -H "Accept: application/json" -H "Content-Type: application/json" -d "$_REPO_JSON" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/"
  curl -v -X POST -H "Content-Type: text/plain" -u "$_NEXUS_USER:$_NEXUS_PWD" "${_NEXUS_URL}/service/siesta/rest/v1/script/$_REPO_ID/run"
}


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

# Nexus Repos
add_npm_proxy npm admin admin123 "http://nexus-gl-oc-demo-ci-cd.glpractices.com"

# Create Front-End Build(s)
DEV_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/dev-builds-template-front-end.yaml"

oc process -f $DEV_FT_TEMPLATE -n gl-oc-demo-ci-cd-dev > temp/dev-front-end.yaml 
oc create -f temp/dev-front-end.yaml -n gl-oc-demo-ci-cd-dev

read -p "Press enter to continue"