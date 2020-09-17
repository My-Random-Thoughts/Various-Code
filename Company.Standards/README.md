# Company.Standards PowerShell Module
## Introduction
As part of treating your servers like cattle and not pets comes the need to a standard naming convention.  This is usually a written down expression on what the standard is and how to use it.

As people move into automation, validating the server names becomes important so various code is written to test for it.  This can range from lots of `If` statements (bad) to a nicely created regular expression (best).

Let’s use the following fictional server name in our examples:  `DC1LVWINAPP001`
It breaks down as follows:

  `DC1` Location: *Data Center 1*
  `LV` Environment: *Live*
  `WIN` Operating System: *Windows*
  `APP` Server Role: *Application*
  `001` Numeric ID: *001*

Writing a regular expression for this should be fairly simple, you would just need to make sure all possible values are accounted for:

    ^(DC1|DC2)(LV|DR|PP)(WIN|LNX)(APP|WEB|SQL)(\d{3})$

That’ll work.  It’s simple and will validate for our servers.  We’ll now use that in hundreds of scripts around the company.

The problem is now we need to add a new server role to the list. We are building email servers now with a role code of `EML`.  We have to update all those scripts now.  Sad face.

The solution is a PowerShell module that can be easily updated and will contain more information that a single RegEx can.

---

## Module
### Get-DataCenter
The module is a collection of several scripts, one for each of the sections of our standard.  Each sectional script is basically the same (excluding the numerical id) the only difference is the data it holds, we we'll just look at the first one: `Get-DataCenter`.

    Function Get-DataCenter {
        Param (
            [switch]$RegexOnly
        )

        $Data = @(
            [pscustomobject]@{ Name = 'DC1'; DisplayName = 'London';        Address =     '123 Any Street, London' }
            [pscustomobject]@{ Name = 'DC2'; DisplayName = 'New York';      Address =     '42nd 1st Street, New York' }
            [pscustomobject]@{ Name = 'DC3'; DisplayName = 'Tokyo';         Address =     '...' }
            [pscustomobject]@{ Name = 'AZ1'; DisplayName = 'Azure UK East'; Address =     'Cloud Based' }
            [pscustomobject]@{ Name = 'AZ2'; DisplayName = 'Azure UK West'; Address =     'Cloud Based' }
        )

        If ($RegexOnly.IsPresent) {
            Return "(?<Location>$($Data.Name -join '|'))"
        }

        Return $Data
    }

As we can see, we have 5 data centers listed, each has a name, a friendly display name and the address.  We could include any other information if we needed.  If we execute this function now, we would get the following output:

    Name DisplayName   Address
    ---- -----------   -------
    DC1  London        123 Any Street, London
    DC2  New York      42nd 1st Street, New York
    DC3  Tokyo         ...
    AZ1  Azure UK East Cloud Based
    AZ2  Azure UK West Cloud Based

or with the `-RegexOnly` switch:

    (?<Location>DC1|DC2|DC3|AZ1|AZ2)

Note the `<Location>` label in the RegEx, we'll come to that later.  This script is now our single version of the truth for our module.  If we need to add a new data center location, we just need to add a new data entry, and roll out an updated module.  Simple!


### Putting It All Together
As mentioned above, the other section scripts are the same just with different data and a different `<...>` label string.  Now that we have all our sections, we need to put them together.  The script `Get-ServerNameRegex` does this for us is a simple way that allows for any order of the sections to be used.

Executing the function returns the following string:

    ^(?<Location>DC1|DC2|DC3|AZ1|AZ2)(?<OS>APL|DOS|LNX|NET|WIN)(?<Environment>CT|DR|DV|LV|PP|PR)(?<Role>APP|BLD|DCS|DEV|FIL|SCO|SQL|WEB)(?<Number>00\d|0\d{2}|\d{3})$

It's a little more complicated than our original RegEx at the start of this!  Now that we have this we can start doing patten matching:

    > 'DC1LVWINAPP001' -match (Get-ServerNameRegex)
    True

Great, the RegEx works.  But what about that `<Location>` label in the string.  Well if we look at the automatically created `$Matches` variable, we'll see the following output:

    > $Matches
    Name                           Value
    ----                           -----
    Number                         001
    Location                       DC1
    Environment                    LV
    Role                           APP
    OS                             WIN
    0                              DC1LVWINAPP001

`$Matches` is a custom object that now contains all our labels.  Clever right?

---

## Conclusion
This is a great way to keep your validation scripts up to date when company standards change.  This module can also be expanded to include any other type of validation data that you may need to keep on top of within your scripts.

The code here is just an example and can be used as a template within your company if you wish.  Have fun with it, and help keep your server name validation up to date.

Just a quick note, none of these functions include any comment-based help to help cut down on the length, but you really should use it as much as you can.

Enjoy.
