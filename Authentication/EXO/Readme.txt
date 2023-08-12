So far I can connect using 
Connect-ExchangeOnline -CertificateThumbPrint $env:AutoMike.AADCertThumbprint -AppID $env:AutoMikeAppId -Organization $env:AutoMikeTenantID
But only if I've manually given the API permissions of Office 365 Exchange Online to manage directory. - Still need to figure out how to do this programatically (Delegated Permissions)
investigate what app permissions does differently.


Yeah none of this is working right now. Revisit.
Thinking I may have to go token after all.






