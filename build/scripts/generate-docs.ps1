param(
    [string]$branch = "live",
    [string]$token
)

# Yes, this is ignoring the parameter passed in by VSTS; we don't need the 
# parameter, but we can't remove it until all the active branches don't need it
$branch = "live"

$mdoc = '..\..\tools\mdoc\mdoc.exe'
$docsUri = "https://$token@github.com/xamarin/Xamarin.Forms-api-docs.git"

function StripNodes {
    Param($file, $xpaths)

    [xml]$xml = Get-Content $file -Encoding UTF8

    $xpaths | % {

        $node = $xml.SelectSingleNode($_)

        while ($node -ne $null) {
         $x = $node.ParentNode.RemoveChild($node) 
         $node = $xml.SelectSingleNode($_)
        }

    }

    $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
    $streamWriter = New-Object System.IO.StreamWriter($file, $false, $utf8WithoutBom)
    
    $xml.Save($streamWriter)
    $streamWriter.Close()
}

pushd ..\..

mkdir docstemp
pushd docstemp

# Default Language Stuff
# Clone Xamarin.Forms-api-docs in docstemp\Xamarin.Forms-api-docs
git clone -qb $branch --single-branch $docsUri 

pushd .\Xamarin.Forms-api-docs

# Run mdoc
& $mdoc export-msxdoc .\docs

# Put the results in the docs folder (where NuGet will find it)
mv Xamarin.Forms.*.xml ..\..\docs -Force

# Return from the default language folder
popd

# Translations stuff

$translations = 
@{"lang" = "de-de"; "target" = "de"},
@{"lang" = "es-es"; "target" = "es"},
@{"lang" = "fr-fr"; "target" = "fr"},
@{"lang" = "it-it"; "target" = "it"},
@{"lang" = "ja-jp"; "target" = "ja"},
@{"lang" = "ko-kr"; "target" = "ko"},
@{"lang" = "pt-br"; "target" = "pt-br"},
@{"lang" = "ru-ru"; "target" = "ru"},
@{"lang" = "zh-cn"; "target" = "zh-Hans"},
@{"lang" = "zh-tw"; "target" = "zh-Hant"}
#@{"lang" = "cs-cz"; "target" = "cs"},
#@{"lang" = "pl-pl"; "target" = "pl"},
#@{"lang" = "tr-tr"; "target" = "tr"},


$branch = "live"

$translations | % {
    # Generate the URI for each translated version
    $translationUri = "https://$token@github.com/xamarin/Xamarin.Forms-api-docs.$($_.lang).git"
    $translationFolder = ".\Xamarin.Forms-api-docs.$($_.lang)"
    
    # Clone the translation repo
    git clone -qb $branch --single-branch $translationUri

    # Go into the language-specific folder
    pushd $translationFolder\docs

    # Copy everything over the stuff in the default language folder 
    # (So untranslated bits still remain in the default language)
    copy-item -Path . -Destination ..\..\Xamarin.Forms-api-docs -Recurse -Force -Exclude index.xml

    # Return from the language-specific folder
    popd

    # Go into the default language folder
    pushd .\Xamarin.Forms-api-docs

    Write-Host "Stripping out unused XML for $($_.lang)"

    dir .\docs -R *.xml | Select -ExpandProperty FullName | % {
    
        $xpaths = "//remarks",
            "//summary[text()='To be added.']",
            "//param[text()='To be added.']",
            "//returns[text()='To be added.']",
            "//typeparam[text()='To be added.']",
            "//value[text()='To be added.']",
            "//related",
            "//example"

        StripNodes $_ $xpaths 
    }

    # Run mdoc
    & $mdoc export-msxdoc .\docs

    # And put the results in the language specific folder under docs
    $dest = "..\..\docs\$($_.target)"
    mkdir $dest
    mv Xamarin.Forms.*.xml $dest -Force

    # Return from the default language folder
    popd
}

popd

del docstemp -R -Force

popd