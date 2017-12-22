#######################################################

#参考ドキュメント：SQL Server Integration Services パッケージを Azure にデプロイする
#https://docs.microsoft.com/ja-jp/azure/data-factory/tutorial-deploy-ssis-packages-azure

# 変数設定

# Azure Data Factory version 2 information 
# If your input contains a PSH special character, e.g. "$", precede it with the escape character "`" like "`$". 
$SubscriptionId = "********-****-****-****-********"　#対象のサブスクリプションIDを指定
$ResourceGroupName = "****" #作成するリソースグループ名

# Data factory name. Must be globally unique
$DataFactoryName = "****" #作成するDatafactory名
$DataFactoryLocation = "EastUS"  #今回構成するDatafactoryおよびAzure SQL Server等のロケーション　とりあえずプレビューなので、EastUS推奨

# Azure-SSIS integration runtime information. This is a Data Factory compute resource for running SSIS packages
$AzureSSISName = "****"　#Azure SSIS 統合IRの名称
$AzureSSISDescription = "Azure SSIS Deploy Test"　#Azure SSIS 統合IRの説明
$AzureSSISLocation = "EastUS" #Azure SSIS 統合IRのロケーション。とりあえずEastUS推奨

 # In public preview, only Standard_A4_v2, Standard_A8_v2, Standard_D1_v2, Standard_D2_v2, Standard_D3_v2, Standard_D4_v2 are supported
$AzureSSISNodeSize = "Standard_A4_v2"　#Azure SSIS 統合IRのサイズ　サンプルがA4_v2だったので、そのまま

# In public preview, only 1-10 nodes are supported.
$AzureSSISNodeNumber = 2 
# In public preview, only 1-8 parallel executions per node are supported.
$AzureSSISMaxParallelExecutionsPerNode = 2 

$SQLServerName = "****"　#Azure SQL Serverも一緒に構成したいので、名称を設定
$FirewallIPAddress = '***.***.***.***'　#最終的にSSMSでローカルから接続するので、接続するグローバルIPを指定
$today = '****' #FirewallIpAddressを開ける際に利用する名称用の日付。別に無くても大丈夫

# SSISDB info
$SSISDBServerEndpoint = $SQLServerName + ".database.windows.net"　#SSISデプロイ用DBのサーバー名。手動でサーバーを指定したい場合は変更してね。
$SSISDBServerAdminUserName = "****"　#サーバーのログインユーザーID。Azure SQL Serverと共通のものを利用
$SSISDBServerAdminPassword = "****"　#サーバーのログインパスワード。Azure SQL Serverと共通のものを利用
# Remove the SSISDBPricingTier variable if you are using Azure SQL Managed Instance (private preview)
# This parameter applies only to Azure SQL Database. For the basic pricing tier, specify "Basic", not "B". For standard tiers, specify "S0", "S1", "S2", 'S3", etc.
$SSISDBPricingTier = "S0" #SSIS用DBのプライシング。お好きなものをどうぞ。

#######################################################

#ログイン
Login-AzureRmAccount
Select-AzureRmSubscription -SubscriptionId $SubscriptionId

# Resource Group 作成
New-AzureRmResourceGroup -Location $DataFactoryLocation -Name $ResourceGroupName

# Azure SQL Server 作成　この時点ではDBは作らず。Serverの設定のみ
New-AzureRmSqlServer -ResourceGroupName $ResourceGroupName `
-ServerName $SQLServerName `
  -Location $DataFactoryLocation `
  -SqlAdministratorCredentials $(New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $SSISDBServerAdminUserName, $(ConvertTo-SecureString -String $SSISDBServerAdminPassword -AsPlainText -Force))

New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName `
    -ServerName $SQLServerName `
    -FirewallRuleName "ClientIPAddress_$today" -StartIpAddress $FirewallIPAddress -EndIpAddress $FirewallIPAddress

New-AzureRmSqlServerFirewallRule -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -AllowAllAzureIPs

#Datafactory 作成　必ずV2にすること。V1は未対応。　
#ちなみに最新のAzure Powershell Moduleがない場合こけます。こけた場合、以下を参照して、最新版を入れてね。
#https://docs.microsoft.com/ja-jp/powershell/azure/install-azurerm-ps?view=azurermps-5.1.1
Set-AzureRmDataFactoryV2 -ResourceGroupName $ResourceGroupName `
    -Location $DataFactoryLocation `
    -Name $DataFactoryName

# Azure IR 作成
$secpasswd = ConvertTo-SecureString $SSISDBServerAdminPassword -AsPlainText -Force
$serverCreds = New-Object System.Management.Automation.PSCredential($SSISDBServerAdminUserName, $secpasswd)
Set-AzureRmDataFactoryV2IntegrationRuntime  -ResourceGroupName $ResourceGroupName `
                                            -DataFactoryName $DataFactoryName `
                                            -Name $AzureSSISName `
                                            -Type Managed `
                                            -CatalogServerEndpoint $SSISDBServerEndpoint `
                                            -CatalogAdminCredential $serverCreds `
                                            -CatalogPricingTier $SSISDBPricingTier `
                                            -Description $AzureSSISDescription `
                                            -Location $AzureSSISLocation `
                                            -NodeSize $AzureSSISNodeSize `
                                            -NodeCount $AzureSSISNodeNumber `
                                            -MaxParallelExecutionsPerNode $AzureSSISMaxParallelExecutionsPerNode 

##################################

#Azure IR の実行　かなり時間がかかるので気長に待ちましょう。
write-host("##### Starting your Azure-SSIS integration runtime. This command takes 20 to 30 minutes to complete. #####")
Start-AzureRmDataFactoryV2IntegrationRuntime -ResourceGroupName $ResourceGroupName `
                                             -DataFactoryName $DataFactoryName `
                                             -Name $AzureSSISName `
                                             -Force

write-host("##### Completed #####")
write-host("If any cmdlet is unsuccessful, please consider using -Debug option for diagnostics.")    




