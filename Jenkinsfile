pipeline {
    agent any
    tools {
        jdk 'jdk21'
        nodejs 'node22'
    }
    environment {
        SCANNER_HOME = tool 'sonar-scanner'
        APP_NAME = "reddit-clone-pipeline"
        RELEASE = "1.0.0"
        DOCKER_USER = "shinct123"
        IMAGE_NAME = "${DOCKER_USER}" + "/" + "${APP_NAME}"
        IMAGE_TAG = "${RELEASE}-${BUILD_NUMBER}"
		JENKINS_API_TOKEN = credentials("JENKINS_API_TOKEN")
    }
    stages {
        stage('clean workspace') {
            steps {
                cleanWs()
            }
        }
        stage('Checkout from Git') {
            steps {
                git branch: 'main', url: 'https://github.com/toannct10/reddit-clone-app-ci.git'
            }
        }
        stage("Sonarqube Analysis") {
            steps {
                withSonarQubeEnv('SonarQube-Server') {
                    sh '''$SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Reddit-Clone-CI \
                    -Dsonar.projectKey=Reddit-Clone-CI'''
                }
            }
        }
        stage("Quality Gate") {
            steps {
                script {
                    waitForQualityGate abortPipeline: false, credentialsId: 'SonarQube'
                }
            }
        }
		stage('Install Dependencies') {
		    steps {
		        sh '''
		            echo "Node version:"
		            node --version
		
		            echo "NPM version:"
		            npm --version
		
		            npm cache verify
		            npm install --no-audit --no-fund
		        '''
		    }
		}
        stage('TRIVY FS SCAN') {
            steps {
                sh "trivy fs . > trivyfs.txt"
             }
         }
	 stage("Build & Push Docker Image") {
			steps {
				script {
					docker.withRegistry('https://index.docker.io/v1/', 'dockerhub') {
						docker_image = docker.build("${IMAGE_NAME}")
						docker_image.push("${IMAGE_TAG}")
						docker_image.push('latest')
					}
				}
			}
		}
	 stage("Trivy Image Scan") {
             steps {
                 script {
	              sh ('docker run -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image shinct123/reddit-clone-pipeline:latest --no-progress --scanners vuln  --exit-code 0 --severity HIGH,CRITICAL --format table > trivyimage.txt')
                 }
             }
         }
	 stage ('Cleanup Artifacts') {
             steps {
                 script {
                      sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG}"
                      sh "docker rmi ${IMAGE_NAME}:latest"
                 }
             }
         }
	stage("Trigger CD Pipeline") {
            steps {
                script {
                    sh "curl -v -k --user toan:${JENKINS_API_TOKEN} -X POST -H 'cache-control: no-cache' -H 'content-type: application/x-www-form-urlencoded' --data 'IMAGE_TAG=${IMAGE_TAG}' 'ec2-56-10-68-178.ap-southeast-1.compute.amazonaws.com:8080/job/Reddit-Clone-CD/buildWithParameters?token=gitops-token'"
                }
            }
         }
	}
     post {
        always {
           emailext attachLog: true,
               subject: "'${currentBuild.result}'",
               body: "Project: ${env.JOB_NAME}<br/>" +
                   "Build Number: ${env.BUILD_NUMBER}<br/>" +
                   "URL: ${env.BUILD_URL}<br/>",
               to: 'anhkoquen7@gmail.com',                              
               attachmentsPattern: 'trivyfs.txt,trivyimage.txt'
        }
     }
    
}
