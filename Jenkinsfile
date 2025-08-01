pipeline {
    agent any

    tools {
        jdk 'jdk17'
        nodejs 'node16'
    }

    environment {
        APP_NAME    = "hotstar"
        DOCKER_USER = "naveen90234"
        IMAGE_NAME  = "${DOCKER_USER}/${APP_NAME}"
        IMAGE_TAG   = "${BUILD_NUMBER}"
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

        stage("Trivy Image Scan") {
            steps {
                sh '''
                    trivy image \
                        --scanners vuln \
                        --exit-code 0 \
                        --severity HIGH,CRITICAL \
                        --format table ${IMAGE_NAME}:${IMAGE_TAG} \
                        --output trivy-image-report.html
                '''
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
                sh "docker rmi ${IMAGE_NAME}:${IMAGE_TAG} || true"
            }
        }

        stage("Update the Deployment Tags") {
            steps {
                sh '''
                    echo "Before Update:"
                    cat K8S/deployment.yml

                    sed -i 's|image: .*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g' K8S/deployment.yml

                    echo "After Update:"
                    cat K8S/deployment.yml
                '''
            }
        }

        stage("Push the changes to SCM") {
            environment {
                GIT_REPOSITORY = "hotstar-clone"
                GIT_USERNAME   = "naveen90234"
            }
            steps {
                withCredentials([string(credentialsId: 'github-cred', variable: 'GIT_TOKEN')]) {
                    sh '''
                        git config user.name "${GIT_USERNAME}"
                        git config user.email "nc90234@gmail.com"
                        git add K8S/deployment.yml
                        git commit -m "Update deployment manifest with image tag ${IMAGE_TAG}" || echo "No changes to commit"
                        git push https://${GIT_TOKEN}@github.com/${GIT_USERNAME}/${GIT_REPOSITORY}.git HEAD:main
                    '''
                }
            }
        }

        stage("Kubernetes Deployment") {
            steps {
                withKubeConfig(credentialsId: 'kind-kubeconfig', restrictKubeConfigAccess: true) {
                    sh "kubectl apply -f K8S/deployment.yml"
                    sh "kubectl apply -f K8S/service.yml"
                }
            }
        }

        stage("Kubernetes Verification") {
            steps {
                withKubeConfig(credentialsId: 'kind-kubeconfig', restrictKubeConfigAccess: true) {
                    sh "kubectl get pods -n webapps || kubectl get pods"
                    sh "kubectl get services -n webapps || kubectl get services"
                }
            }
        }
    }
}
