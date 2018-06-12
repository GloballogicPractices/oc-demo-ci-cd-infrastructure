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
oc new-project gl-oc-demo-ci-cd-test --display-name="GL OC Demo CI\CD Test"
oc new-project gl-oc-demo-ci-cd-prod --display-name="GL OC Demo CI\CD Prod"

oc import-image tnozicka/s2i-centos7-golang:latest --confirm=true -n gl-oc-demo-ci-cd

oc adm policy add-scc-to-user anyuid -z default -n gl-oc-demo-ci-cd-dev
oc adm policy add-scc-to-user anyuid -z default -n gl-oc-demo-ci-cd-test
oc adm policy add-scc-to-user anyuid -z default -n gl-oc-demo-ci-cd-prod


oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd

oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd-dev
oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd-dev -n gl-oc-demo-ci-cd-dev

oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd-test
oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd-test -n gl-oc-demo-ci-cd-test

oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd -n gl-oc-demo-ci-cd-prod
oc adm policy add-role-to-group admin system:serviceaccounts:gl-oc-demo-ci-cd-prod -n gl-oc-demo-ci-cd-prod

oc adm pod-network join-projects --to=gl-oc-demo-ci-cd gl-oc-demo-ci-cd-dev gl-oc-demo-ci-cd-test gl-oc-demo-ci-cd-prod

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

# Deploy Jenkins
oc new-app jenkins-ephemeral -l app=jenkins -p MEMORY_LIMIT=1Gi -n gl-oc-demo-ci-cd
sleep 5
oc set resources dc/jenkins --limits=cpu=1,memory=2Gi --requests=cpu=200m,memory=1Gi -n gl-oc-demo-ci-cd
oc rollout status dc jenkins -n gl-oc-demo-ci-cd

oc delete route jenkins -n gl-oc-demo-ci-cd
oc expose service jenkins -n gl-oc-demo-ci-cd

# Create Service Deployment(s)
for SVC in rabbitmq carts-db catalogue-db orders-db session-db user-db catalogue carts orders payment queue-master shipping user
  do
    DEP_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/deploy-template-$SVC.yaml"
    echo "Processing template: $DEP_TEMPLATE"

	for PRJ in dev test prod
  	  do
  	  	NAMESPACE="gl-oc-demo-ci-cd-$PRJ"
	    HOSTNAME_SUFFIX="$NAMESPACE.glpractices.com"

		oc process -f $DEP_TEMPLATE -n $NAMESPACE --param=HOSTNAME_SUFFIX=$HOSTNAME_SUFFIX > temp/$PRJ-$SVC.yaml 
		oc create -f temp/$PRJ-$SVC.yaml -n $NAMESPACE

	  done
  done

# Create Front-End Build(s)
BLD_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/builds-template-front-end.yaml"
GIT_URI="https://github.com/andriy-gnennyy-gl/oc-demo-ci-cd-front-end"
GIT_REF="dev"

oc process -f $BLD_FT_TEMPLATE -n gl-oc-demo-ci-cd-dev --param=GIT_URI=$GIT_URI --param=GIT_REF=$GIT_REF > temp/dev-front-end.yaml 
oc create -f temp/dev-front-end.yaml -n gl-oc-demo-ci-cd-dev

GIT_REF="master"

oc process -f $BLD_FT_TEMPLATE -n gl-oc-demo-ci-cd-test --param=GIT_URI=$GIT_URI --param=GIT_REF=$GIT_REF > temp/test-front-end.yaml 
oc create -f temp/test-front-end.yaml -n gl-oc-demo-ci-cd-test

# Create Front-End Deployment(s)
DEP_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/deploy-template-front-end.yaml"
HOSTNAME_SUFFIX="gl-oc-demo-ci-cd-dev.glpractices.com"

oc process -f $DEP_FT_TEMPLATE -n gl-oc-demo-ci-cd-dev --param=HOSTNAME_SUFFIX=$HOSTNAME_SUFFIX > temp/dev-front-end.yaml 
oc create -f temp/dev-front-end.yaml -n gl-oc-demo-ci-cd-dev

HOSTNAME_SUFFIX="gl-oc-demo-ci-cd-test.glpractices.com"

oc process -f $DEP_FT_TEMPLATE -n gl-oc-demo-ci-cd-test --param=HOSTNAME_SUFFIX=$HOSTNAME_SUFFIX > temp/test-front-end.yaml 
oc create -f temp/test-front-end.yaml -n gl-oc-demo-ci-cd-test

DEP_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/bluegreen-template-front-end.yaml"
HOSTNAME_SUFFIX="gl-oc-demo-ci-cd-prod.glpractices.com"

oc process -f $DEP_FT_TEMPLATE -n gl-oc-demo-ci-cd-prod --param=HOSTNAME_SUFFIX=$HOSTNAME_SUFFIX > temp/prod-front-end.yaml 
oc create -f temp/prod-front-end.yaml -n gl-oc-demo-ci-cd-prod

DEP_FT_TEMPLATE="https://raw.githubusercontent.com/andriy-gnennyy-gl/oc-demo-ci-cd-infrastructure/master/pipeline-template-front-end.yaml"

oc process -f $DEP_FT_TEMPLATE -n gl-oc-demo-ci-cd > temp/prod-front-end.yaml 
oc create -f temp/prod-front-end.yaml -n gl-oc-demo-ci-cd

read -p "Press enter to continue"