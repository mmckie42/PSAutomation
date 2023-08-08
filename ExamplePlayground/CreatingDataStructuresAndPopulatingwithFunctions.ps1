#learing how to build data objects from functions


#This builds the data structure and exists outside of the functions scope that populates it
$inputs = $null #null out for testing repeat runs
$inputs = @{
    'Firstname' = ''
    'SecondName' = ''
    'Email' = ''
}
#simple function to populate the simulated input, imagine this was taking some input from something and 
#storing the data in an object to use in later stuff
function popdeets() {
    $inputs.firstname = 'Mike'
    $inputs.secondname = 'Lawry'
    $inputs.email = 'm.lawry@anoldmovie.com'
}

#storing the populated data in a container that could contain other data blocks for use in other tools
$userdetails = $null
$userdetails = @{
    'contactdeets' = $inputs
}

#simple function to write to console showing the values
#could have used values straight from form but this is how to use them when embedded in a container object

function writedeets() {
    Write-Host "
    User will be created with the following deets:
    Firstname - $($userdetails.contactdeets.firstname)
    Secondname - $($userdetails.contactdeets.SecondName)
    Email - $($userdetails.contactdeets.Email)
    "
}

Write-Host "Use writedeets to show empty, popdeets to populate with hard coded values, and writedeets again to show the changes." -ForegroundColor Green