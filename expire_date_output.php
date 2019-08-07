<?php
# -*-PHP-script-*-
#
/**
 * Title    : SSL certification expire date output"
 * Auther   : Alex, Lee
 * Created  : 10-12-2018
 * Modified : 10-12-2018
 * E-mail   : cine0831@gmail.com
**/

# For PHP >= 5.3.0 use this
if (version_compare(phpversion(), '5.3.0', '>=')) {
    $hostname = gethostname();
}

# For PHP < 5.3.0 but >= 4.2.0 use this
if (version_compare(phpversion(), '4.2.0', '>=')) {
    if (version_compare(phpversion(), '5.3.0', '<')) {
        $hostname = php_uname('n');
    }
}

# For PHP < 4.2.0 use this
if (version_compare(phpversion(), '4.2.0', '<')) {
    $hostname = getenv('HOSTNAME'); 
    if(!$hostname) $hostname = exec('echo $HOSTNAME');
}

# __ssl_expired_check__
function ssl_expired($ssl_file) {
    global $hostname;
    global $result_file;

    $ssl_file = trim($ssl_file);

    #if (is_file($ssl_file)) {
    #     echo $ssl_file . " : test";
    #} else {
    #     echo $ssl_file . " : is no file";
    #}

    $data = openssl_x509_parse(file_get_contents($ssl_file));
    $validTo = date('Y-m-d', $data['validTo_time_t']);
    echo $validTo;
}

# __Main__
ssl_expired($argv[1]);

?>
