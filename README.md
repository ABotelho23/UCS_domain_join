# UCS_domain_join

Script for a more generic Linux workstation domain join to Univention Corporate Server. Uses SSSD with some tweaks to make sure the computer actually shows up as "Linux" and not "Windows Workstation/Server". Tested on Ubuntu 20.04. Intention is to expand its use to more distros that support SSSD.

Based on Univention Corporate Server documentation that can be found here: https://docs.software-univention.de/domain-4.4.html

1. Clone the repo
`git clone https://github.com/ABotelho23/UCS_domain_join`

2. Change directory
`cd UCS_domain_join`

3. Run the script
`sudo bash setup.sh`

4. Follow the prompts.
