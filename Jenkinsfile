pipeline {
    agent any
    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }
    environment {
        SCANNER_HOME = tool "sonar-scanner"
        APP_NAME = "hotstar"
        DOCKER_USER = "naveen90234"
        IMAGE_NAME = "${DOCKER_USER}/${APP_NAME}"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    stages {
        stage("Clean Workspace") {
            steps {
                cleanWs()
            }
        }

        stage("Checkout from Git") {
            steps {
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/naveen90234/hotstar-clone'
            }
        }

        // === Skipped: SonarQube Analysis ===
        // stage("SonarQube Analysis") {
        //     steps {
        //         withSonarQubeEnv('sonar-server') {
        //             sh '''$SCANNER_HOME/bin/sonar-scanner \
        //                 -Dsonar.projectName=Hotstar \
        //                 -Dsonar.projectKey=Hotstar'''
        //         }
        //     }
        // }

        // === Skipped: SonarQube Quality Gate ===
        // stage('SonarQube Quality Gate') {
        //     steps {
        //         timeout(time: 5, unit: 'MINUTES') {
        //             waitForQualityGate abortPipeline: true
        //         }
        //     }
        // }

        stage("Install Dependencies") {
            steps {
                sh "npm install"
            }
        }

        stage("OWASP FS SCAN") {
            steps {
                dependencyCheck additionalArguments: '--scan ./ --disableYarnAudit --disableNodeAudit', odcInstallation: 'DP-Check'
                dependencyCheckPublisher pattern: '**/dependency-check-report.xml'
            }
        }

        stage("Docker Build & Tag Image") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker build -t ${IMAGE_NAME}:${IMAGE_TAG} ."
                    }
                }
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh 'trivy image --scanners vuln --exit-code 0 --severity HIGH,CRITICAL --format table ${IMAGE_NAME}:${IMAGE_TAG} --output trivy-image-report.html'
            }
        }

        stage("Push Docker Image to Docker Hub") {
            steps {
                script {
                    withDockerRegistry(credentialsId: 'docker-cred', toolName: 'docker') {
                        sh "docker push ${IMAGE_NAME}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage("Clean Artifacts") {
            steps {
                sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG}"
            }
        }

        stage("Update the Deployment Tags") {
            steps {
                sh """
                    cat K8S/deployment.yml
                    sed -i 's|image: ${IMAGE_NAME}:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g' K8S/deployment.yml
                    cat K8S/deployment.yml
                """
            }
        }

        stage("Push the changes to SCM") {
            environment {
                GIT_REPOSITORY = "hotstar-clone"
                GIT_USERNAME = "naveen90234"
            }
            steps {
                withCredentials([string(credentialsId: 'github-cred', variable: 'github')]) {
                    sh '''
                        git config user.name "naveen90234"
                        git config user.email "nc90234@gmail.com"
                        git add K8S/deployment.yml
                        git commit -m "Update deployment manifest with image tag ${IMAGE_TAG}"
                        git push https://${github}@github.com/${GIT_USERNAME}/${GIT_REPOSITORY} HEAD:main
                    '''
