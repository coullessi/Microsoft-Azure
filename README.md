# Azure Arc-enabled servers

In this lab exercise, you'll learn to connect machines to Azure at scale using a group policy object or Ansible. But what is Azure Arc and how can it be beneficial to your organization? Azure Arc is a Microsoft Azure solution that allows you to manage Windows and Linux servers hosted outside of Azure; the servers can be on-premises or in other clouds like Google Cloud Platform, or Amazon Web Services. The machines hosted outside of Azure are considered hybrid machines. And when a hybrid device is connected to Azure, it becomes a connected machine and is treated as a resource in Azure. Each connected device has a Resource ID enabling the device to be included in a resource group.
To connect hybrid machines to Azure, you install the [Azure Connected Machine agent](https://learn.microsoft.com/en-us/azure/azure-arc/servers/agent-overview) on each server. This agent doesn't replace the Azure [Log Analytics agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/log-analytics-agent) / [Azure Monitor Agent](https://learn.microsoft.com/en-us/azure/azure-monitor/agents/)azure-monitor-agent-overview as you know it. The Log Analytics agent or the Azure Monitor Agent for Windows and Linux is required in order to:

- Proactively monitor the OS and workloads running on a server.
- Manage the server using Automation runbooks or solutions like Update Management.
- Use other Azure services like [Microsoft Defender for Cloud](https://learn.microsoft.com/en-us/azure/security-center/security-center-introduction). For example, with your Microsoft Defender for Servers plan, you'll be able to automatically onboard your endpoint to Microsoft Defender for Endpoint, once you onboard them to Azure Arc. And there is a great tech community article series titled [The ultimate guide to deciphering Azure Agents and Defender for Servers](https://techcommunity.microsoft.com/t5/fasttrack-for-azure/the-ultimate-guide-to-deciphering-azure-agents-defender-for/ba-p/4110383) that covers when it's appropriate to use Azure Arc.

You can install the Connected Machine agent manually, or on multiple servers at scale, using a [deployment method](https://learn.microsoft.com/en-us/azure/azure-arc/servers/deployment-options) that works best for you.
And in this exercise, we are going to do just that, we are going to onboard, at scale multiple Windows servers to Azure Arc using a Group Policy Object and an Ansible playbook for Linux Servers.

>[!Important]
In addition to the __lab resource files__, please go to the [video](https://youtu.be/1qCiTYG2fgI?si=qmCQj8Kw4GBxOy81) recording for a step-by-step process to onboard your servers to Azure Arc.

## Lab resources

| Windows Server | Linux Servers |
| ------------- | ------------- |
| [Onboard Server to Azure Arc](/AzureArc/Windows/New-AzLabArcServer.ps1) | [Configure ansible control node](/AzureArc/Linux/Ansible/config_control_node.sh) |
|  | [Ansible playbook](/AzureArc/Linux/Ansible/config_azurearc.yml) |
|  | [Sample hosts file](/AzureArc/Linux/Ansible/hosts) |
|  | [Remove Azure connect agent from devices](/AzureArc/Linux/Ansible/remove_azurearc.yml) |
|  | [Script to create a service principal](/AzureArc/Linux/PSScripts/create_service_principal.ps1) |

**Video playlist: [Azure Arc-enabled servers step-by-step guide](https://www.youtube.com/playlist?list=PLDI76x8X-DfY7qkJGn1iob52F2Nh0mO5t)**  

## Documentation

[What is Azure Arc-Enabled Servers?](https://learn.microsoft.com/en-us/azure/azure-arc/servers/overview)  
[Prerequisites](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites)  
[Network requirements](https://learn.microsoft.com/en-us/azure/azure-arc/servers/prerequisites)  
[Connect machines at scale using Group Policy](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-group-policy-powershell)  
[Connect machines at scale using Ansible playbooks](https://learn.microsoft.com/en-us/azure/azure-arc/servers/onboard-ansible-playbooks)

---

[![LinkeIn](./AzureArc/Images//LinkeIn.png)](https://www.linkedin.com/in/c-lessi/)
[![YouTube](./AzureArc/Images/YouTube.png)](https://www.youtube.com/playlist?list=PLDI76x8X-DfY7qkJGn1iob52F2Nh0mO5t)
