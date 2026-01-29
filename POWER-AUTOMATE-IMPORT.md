# <img style="vertical-align: middle" src='assets/images/power-automate.png' width='40' height='40' /> Power Automate import

How to distribute Automation artifacts

## 🧩 Elements
### Flow 
The elements we have in Power automate are Flows. This is the automation itself. They consist of Triggers and Actions, etc...
In order to keep automations secure, the platform provides Connectors. E.g. een Outlook 365 connector. \
That connector is specifically for you as a user; it contains your credentials. \
Passing a Flow using your connector to anyone is like giving the keys of your residential house.  Security = none.

### Solution
So within the platform there is something like a *Solution* you *can* distribute to others. \  
Such Solution contains your flow, but instead of the actual connector, it had connector references, that can be replaced. 
At importing time, process allows you to select *your* connector, using your credentials. 

### Not perfect
Solutions aren't perfect though. When importing the same solution twice, with the same user, it'll overwrite your flow. \
For development situations this is sufficient for tweaking your Flow and re-trying it after import.  
Your connector stays the same, no worries here. 

Passing the same Solution you made to someone else within your organization can quickly run into import errors. \
The main reason is that the elements of your automation all do have their unique synthetic key, and importing the same key twice results in a duplicate key error.

### Tenant, Environment
Within the Power Automate platform you have the organization, called Tenant your licenses are used.
Your Tenant can be divided into several Environments. This can be used for splitting up departments, but also OTAP targets. 

Solutions that require to be per user (like this repo provides) can achieve that by creating an Environment per user, and deploy their Solution as much as they like, without duplicate key errors.
As Environments aren't really meant for that, and would require administrative work, this isn't an option.

## <img style="vertical-align: middle" src='assets/images/power-automate.png' width='20' height='20' /> Power Platform Catalog 
For Premium licenses the Power Automate platform provides an organization-wide store where you can export your solutions to.
This allows you to distribute your Solution in a professional way: the **Power Platform Catalog** \
An arbitrary user can go to the Catalog, make his own automation based upon the *template* that was exported earlier. 

At the moment of writing the option of using **Power Platform Catalog** hasn't been tested. \
Looking at [Releases page](../../releases) you'll see brand specific Solutions pre-build, ready to download. \
Those are the Solutions you'd want to import into the Power Platform catalog; a sustainable solution for your distribution problem. \
What the Catalog does when you import from it, it strips all synthetic keys and makes new ones for that user. 

However, users that aren't operating under a Premium license (like Office 365 Standard) should also be able to enjoy the automation built in this repo. Hence, an answer below to this issue.  

## <img style="vertical-align: middle" src='assets/images/github.png' width='20' height='20' /> GitHub Actions Workflows

There are 3 workflows that populate the [Releases page](../../releases). 
### smart-build-solution 
(Automatic build) Auto-detects changes in the repo, and re-builds all brands Solutions, or a specific brand Solution. \
Naming convention: **Latest \<brand name\> Solution Build**. E.g. "Latest volvo Solution Build" \
They can be used for importing in the **Power Platform Catalog**, or for importing in a specific user [Power Automate platform](https:\\make.powerautomate.com). \
However, one needs to be cautious about re-importing it for another user within the same Environment, as it can lead to duplicate key errors.

### build-user-solution 
(Manual build) Overcomes the duplicate key error and strips away the synthetic keys and replaces them by new ones. \
As this build is user specific, it embeds the name of the user to avoid naming collisions. \
The GH Actions workflow will ask for user name and brand. \
When importing in a specific user [Power Automate platform](https:\\make.powerautomate.com), the new synthetic keys won't result in duplicate key errors. \
Naming convention: **Latest \<brand name\> Solution Build (user name)**. E.g. "Latest volvo Solution Build (test.user)" 

### build-solution 
(Manual build) Just like the smart-build-solution, but for a specific brand. \
The GH Actions workflow will ask for user name and brand. \
Naming convention: **Latest \<brand name\> Solution Build**. E.g. "Latest volvo Solution Build" 