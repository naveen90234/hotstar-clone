pipeline{
    agent any
    stages {
        stage('Checkout from Git'){
            steps{
                git branch: 'main', url: 'https://github.com/vinaypo/Hotstar-Clone'
            }
        }
        stage('Terraform version'){
             steps{
                 sh 'terraform --version'
             }
        }
        stage('Terraform init'){
             steps{
                 dir('EKS_TERRAFORM') {
                      sh 'terraform init'
                   }
             }
        }
        stage('Terraform validate'){
             steps{
                 dir('EKS_TERRAFORM') {
                      sh 'terraform validate'
                   }
             }
        }
        stage('Terraform Plan/Apply/Destroy') {
            steps {
                dir('EKS_TERRAFORM') {
                    script {
                        if (action == 'plan') {
                            sh 'terraform plan -input=false'
                        } else if (action == 'apply' || action == 'destroy') {
                            sh "terraform ${action} -auto-approve -input=false"
                        } else {
                            error("Invalid Terraform action: ${action}")
                        }
                    }
                }
            }
        }
    }
}
