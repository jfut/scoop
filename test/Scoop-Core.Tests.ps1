. "$psscriptroot\..\lib\core.ps1"
. "$psscriptroot\..\lib\manifest.ps1"
. "$psscriptroot\..\lib\install.ps1"
. "$psscriptroot\..\lib\unix.ps1"
. "$psscriptroot\Scoop-TestLib.ps1"

$repo_dir = (Get-Item $MyInvocation.MyCommand.Path).directory.parent.FullName
$isUnix = is_unix

describe "url_with_request" {
    it "string url" {
        $url = "http://test1.example.org/file.zip"
        $url = url_with_request $url $null
        $url.address | should be "http://test1.example.org/file.zip"
        $url.request | should be $null

        $url = "http://test1.example.org/file.zip"
        $default_request = [PSCustomObject]@{
            "useragent" = "UserAgent";
        }
        $url = url_with_request $url $default_request
        $url.address | should be "http://test1.example.org/file.zip"
        $url.request.useragent | should be "UserAgent"
    }

    it "pscustomobject url" {
        $request = [PSCustomObject]@{
            "useragent" = "UserAgent";
        }
        $url = [PSCustomObject]@{
            "address" = "http://test1.example.org/file.zip";
            "request" = $request;
        }
        $url = url_with_request $url $null
        $url.address | should be "http://test1.example.org/file.zip"
        $url.request.useragent | should be "UserAgent"

        $url = [PSCustomObject]@{
            "address" = "http://test1.example.org/file.zip";
            "request" = $request;
        }
        $default_request = [PSCustomObject]@{
            "useragent" = "DefaultUserAgent";
        }
        $url = url_with_request $url $default_request
        $url.address | should be "http://test1.example.org/file.zip"
        $url.request.useragent | should be "UserAgent"
    }
}

describe "urls_with_request" {
    beforeall {
        $working_dir = setup_working "manifest"
    }

    it "urls_with_request without architecture" {
        $manifest = parse_json "$working_dir/url_with_request.json"
        $urls = urls_with_request $manifest $null

        $urls[0].address | should be "http://test1.example.org/file.zip"
        $urls[1].address | should be "http://test2.example.org/file.zip"
        $urls[2].address | should be "http://test3.example.org/file.zip"
        $urls[3].address | should be "http://test4.example.org/file.zip"

        $urls[0].request.useragent | should be "Common UserAgent (Scoop/1.0)"
        $urls[1].request.useragent | should be $null
        $urls[2].request.useragent | should be "UserAgent3 (Scoop/1.0)"
        $urls[3].request.useragent | should be ""

        $urls[0].request.referer | should be $null
        $urls[1].request.referer | should be $null
        $urls[2].request.referer | should be $null
        $urls[3].request.referer | should be "http://test4.example.org/file.html"
    }

    it "urls_with_request with architecture" {
        $manifest = parse_json "$working_dir/url_with_request_architecture.json"

        $urls = urls_with_request $manifest "64bit"
        $urls[0].address | should be "http://test1.example.org/file.zip"
        $urls[1].address | should be "http://test2.example.org/file.zip"
        $urls[0].request.useragent | should be "Common UserAgent (Scoop/1.0)"
        $urls[1].request.useragent | should be $null
        $urls[0].request.referer | should be $null
        $urls[1].request.referer | should be $null

        $urls = urls_with_request $manifest "32bit"
        $urls[0].address | should be "http://test3.example.org/file.zip"
        $urls[1].address | should be "http://test4.example.org/file.zip"
        $urls[0].request.useragent | should be "UserAgent3 (Scoop/1.0)"
        $urls[1].request.useragent | should be ""
        $urls[0].request.referer | should be $null
        $urls[1].request.referer | should be "http://test4.example.org/file.html"
    }
}

describe "create_webclient" {
    beforeall {
        $working_dir = setup_working "manifest"
    }

    it "create_webclient" {
        $manifest = parse_json "$working_dir/url_with_request.json"
        $url = url_with_request $manifest.checkver.url $manifest.request

        $env:TEST_CHECKVER_PASSWORD = "password1"
        $wc = create_webclient $url
        $wc.credentials.userName | should be "checkver_user"
        $wc.credentials.password | should be "password1"
        $wc.headers.count | should be 2
        $wc.headers['Referer']  | should be "http://checkver.example.org/"
        $wc.headers['User-Agent'] | should be "Scoop/1.0 (+http://scoop.sh/) (Windows NT 6.1; WOW64)"

        $env:TEST_CHECKVER_PASSWORD = "password2"
        $wc = create_webclient $url
        $wc.credentials.userName | should be "checkver_user"
        $wc.credentials.password | should be "password2"
    }
}

describe "create_webrequest" {
    beforeall {
        $working_dir = setup_working "manifest"
    }

    it "create_webrequest without architecture" {
        $manifest = parse_json "$working_dir/url_with_request.json"
        $urls = urls_with_request $manifest $null

        $wreq = create_webrequest $urls[0] $manifest.cookie
        $wreq.address | should be "http://test1.example.org/file.zip"
        $wreq.credentials | should be $null
        $wreq.headers.count | should be 3
        $wreq.headers['Cookie'] | should be "oraclelicense=accept-securebackup-cookie"
        $wreq.referer | should be "http://test1.example.org/"
        $wreq.useragent | should be "Common UserAgent (Scoop/1.0)"

        $wreq = create_webrequest $urls[1] $manifest.cookie
        $wreq.address | should be "http://test2.example.org/file.zip"
        $wreq.credentials.userName | should be "user2"
        $wreq.credentials.password | should be "pass2"
        $wreq.headers.count | should be 3
        $wreq.headers['Cookie'] | should be "oraclelicense=accept-securebackup-cookie"
        $wreq.referer | should be "http://test2.example.org/"
        $wreq.useragent | should be "Scoop/1.0"

        $wreq = create_webrequest $urls[2] $manifest.cookie
        $wreq.address | should be "http://test3.example.org/file.zip"
        $wreq.credentials | should be $null
        $wreq.headers.count | should be 3
        $wreq.headers['Cookie'] | should be "oraclelicense=accept-securebackup-cookie"
        $wreq.referer | should be "http://test3.example.org/"
        $wreq.useragent | should be "UserAgent3 (Scoop/1.0)"

        $env:TEST_USERNAME = "username1"
        $env:TEST_PASSWORD = "password1"
        $wreq = create_webrequest $urls[3] $manifest.cookie
        $wreq.address | should be "http://test4.example.org/file.zip"
        $wreq.credentials.userName | should be "username1"
        $wreq.credentials.password | should be "password1"
        $wreq.headers.count | should be 4
        $wreq.headers['X-Header1'] | should be "header1"
        $wreq.headers['X-Header2'] | should be "header2"
        $wreq.headers['Cookie'] | should be "oraclelicense=specified-value"
        $wreq.referer | should be "http://test4.example.org/file.html"
        $wreq.useragent | should be $null

        $env:TEST_USERNAME = "username2"
        $env:TEST_PASSWORD = "password2"
        $wreq = create_webrequest $urls[3] $manifest.cookie
        $wreq.credentials.userName | should be "username2"
        $wreq.credentials.password | should be "password2"
    }
}

describe "is_directory" {
    beforeall {
        $working_dir = setup_working "is_directory"
    }

    it "is_directory recognize directories" {
        is_directory "$working_dir\i_am_a_directory" | Should be $true
    }
    it "is_directory recognize files" {
        is_directory "$working_dir\i_am_a_file.txt" | Should be $false
    }

    it "is_directory is falsey on unknown path" {
        is_directory "$working_dir\i_do_not_exist" | Should be $false
    }
}

describe "movedir" {
    $extract_dir = "subdir"
    $extract_to = $null

    beforeall {
        $working_dir = setup_working "movedir"
    }

    it "moves directories with no spaces in path" -skip:$isUnix {
        $dir = "$working_dir\user"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_tmp\$extract_dir" | should not exist
    }

    it "moves directories with spaces in path" -skip:$isUnix {
        $dir = "$working_dir\user with space"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_tmp\$extract_dir" | should not exist

        # test trailing \ in from dir
        movedir "$dir\_tmp\$null" "$dir\another"
        "$dir\another\test.txt" | should contain "testing"
        "$dir\_tmp" | should not exist
    }

    it "moves directories with quotes in path" -skip:$isUnix {
        $dir = "$working_dir\user with 'quote"
        movedir "$dir\_tmp\$extract_dir" "$dir\$extract_to"

        "$dir\test.txt" | should contain "this is the one"
        "$dir\_tmp\$extract_dir" | should not exist
    }
}

describe "unzip_old" {
    beforeall {
        $working_dir = setup_working "unzip_old"
    }

    function test-unzip($from) {
        $to = strip_ext $from

        if(is_unix) {
            unzip_old ($from -replace '\\','/') ($to -replace '\\','/')
        } else {
            unzip_old ($from -replace '/','\') ($to -replace '/','\')
        }

        $to
    }

    context "zip file size is zero bytes" {
        $zerobyte = "$working_dir\zerobyte.zip"
        $zerobyte | should exist

        it "unzips file with zero bytes without error" -skip:$isUnix {
            # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
            # `$to = test-unzip $zerobyte` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
            $to = ([string](test-unzip $zerobyte)).trimStart()

            $to | should not match '^\s'
            $to | should not be NullOrEmpty

            $to | should exist

            (gci $to).count | should be 0
        }
    }

    context "zip file is small in size" {
        $small = "$working_dir\small.zip"
        $small | should exist

        it "unzips file which is small in size" -skip:$isUnix {
            # some combination of pester, COM (used within unzip_old), and Win10 causes a bugged return value from test-unzip
            # `$to = test-unzip $small` * RETURN_VAL has a leading space and complains of $null usage when used in PoSH functions
            $to = ([string](test-unzip $small)).trimStart()

            $to | should not match '^\s'
            $to | should not be NullOrEmpty

            $to | should exist

            # these don't work for some reason on appveyor
            #join-path $to "empty" | should exist
            #(gci $to).count | should be 1
        }
    }
}

describe "shim" {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "links a file onto the user's path" -skip:$isUnix {
        { get-command "shim-test" -ea stop } | should throw
        { get-command "shim-test.ps1" -ea stop } | should throw
        { get-command "shim-test.cmd" -ea stop } | should throw
        { shim-test } | should throw

        shim "$working_dir\shim-test.ps1" $false "shim-test"
        { get-command "shim-test" -ea stop } | should not throw
        { get-command "shim-test.ps1" -ea stop } | should not throw
        { get-command "shim-test.cmd" -ea stop } | should not throw
        shim-test | should be "Hello, world!"
    }

    context "user with quote" {
        it "shims a file with quote in path" -skip:$isUnix {
            { get-command "shim-test" -ea stop } | should throw
            { shim-test } | should throw

            shim "$working_dir\user with 'quote\shim-test.ps1" $false "shim-test"
            { get-command "shim-test" -ea stop } | should not throw
            shim-test | should be "Hello, world!"
        }
    }

    aftereach {
        rm_shim "shim-test" $shimdir
    }
}

describe "rm_shim" {
    beforeall {
        $working_dir = setup_working "shim"
        $shimdir = shimdir
        $(ensure_in_path $shimdir) | out-null
    }

    it "removes shim from path" -skip:$isUnix {
        shim "$working_dir\shim-test.ps1" $false "shim-test"

        rm_shim "shim-test" $shimdir

        { get-command "shim-test" -ea stop } | should throw
        { get-command "shim-test.ps1" -ea stop } | should throw
        { get-command "shim-test.cmd" -ea stop } | should throw
        { shim-test } | should throw
    }
}

describe "ensure_robocopy_in_path" {
    $shimdir = shimdir $false
    mock versiondir { $repo_dir }

    beforeall {
        reset_aliases
    }

    context "robocopy is not in path" {
        it "shims robocopy when not on path" -skip:$isUnix {
            mock gcm { $false }
            gcm robocopy | should be $false

            ensure_robocopy_in_path

            "$shimdir/robocopy.ps1" | should exist
            "$shimdir/robocopy.exe" | should exist

            # clean up
            rm_shim robocopy $(shimdir $false) | out-null
        }
    }

    context "robocopy is in path" {
        it "does not shim robocopy when it is in path" -skip:$isUnix {
            mock gcm { $true }
            ensure_robocopy_in_path

            "$shimdir/robocopy.ps1" | should not exist
            "$shimdir/robocopy.exe" | should not exist
        }
    }
}

describe 'sanitary_path' {
  it 'removes invalid path characters from a string' {
    $path = 'test?.json'
    $valid_path = sanitary_path $path

    $valid_path | should be "test.json"
  }
}

describe 'app' {
    it 'parses the bucket name from an app query' {
        $query = "test"
        $app, $bucket = app $query
        $app | should be "test"
        $bucket | should be $null

        $query = "extras/enso"
        $app, $bucket = app $query
        $app | should be "enso"
        $bucket | should be "extras"

        $query = "test-app"
        $app, $bucket = app $query
        $app | should be "test-app"
        $bucket | should be $null

        $query = "test-bucket/test-app"
        $app, $bucket = app $query
        $app | should be "test-app"
        $bucket | should be "test-bucket"
    }
}
