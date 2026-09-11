<?php

/*
 * dxflow FileGator configuration.
 *
 * Everything the step lets you tune arrives through private/settings.php, which the
 * entrypoint writes from the environment on every start — so a restart with a new
 * --override is the whole reconfiguration story and this file never changes.
 *
 * It is the upstream sample with four differences: the browsed directory is the
 * engine volume rather than the bundled repository/, the private state lives on the
 * volume too (private/ is a symlink to the /data mount), the guest account's
 * permissions decide whether a reader has to sign in at all, and the editable and
 * paginated lists are sized for run directories rather than a web root.
 */

$dx = require __DIR__ . '/private/settings.php';

return [
    'public_path' => APP_PUBLIC_PATH,
    'public_dir' => APP_PUBLIC_DIR,
    'overwrite_on_upload' => $dx['overwrite_on_upload'],
    'timezone' => $dx['timezone'],

    // Opened in the browser instead of downloaded. Text and image types only — a
    // type the browser will execute is what turns a shared drop box into an XSS.
    'download_inline' => ['pdf', 'png', 'jpg', 'jpeg', 'gif', 'txt', 'log', 'csv'],

    'lockout_attempts' => 5,
    'lockout_timeout' => 15,

    'frontend_config' => [
        'app_name' => $dx['app_name'],
        'app_version' => APP_VERSION,
        'language' => 'english',
        'logo' => 'https://filegator.io/filegator_logo.svg',
        'upload_max_size' => $dx['upload_max_size'],
        'upload_chunk_size' => $dx['upload_chunk_size'],
        'upload_simultaneous' => 3,
        'default_archive_name' => 'archive.zip',

        // The files a run is steered by, edited where they already are: a solver
        // dictionary, a parameter file, a job script, a manifest
        'editable' => [
            '.txt', '.log', '.csv', '.tsv', '.json', '.yaml', '.yml', '.toml', '.ini',
            '.cfg', '.conf', '.md', '.sh', '.py', '.R', '.r', '.jl', '.m', '.xml',
            '.mdp', '.top', '.itp', '.gro', '.pdb', '.in', '.dat', '.inp', '.nml',
        ],

        'date_format' => 'YY/MM/DD hh:mm:ss',
        'guest_redirection' => '',
        'search_simultaneous' => 5,

        // The private state directory is inside the volume, so it is inside what the
        // browser shows unless ROOT_DIR moves the root below it — hide it either way
        'filter_entries' => ['.filegator/', '.DS_Store', '@eaDir/', '#recycle/'],

        // An output directory holds more than fifteen files. The first entry is the
        // default, and '' is unlimited — last, so it is a choice and not a surprise.
        'pagination' => [50, 100, 500, ''],
    ],

    'services' => [
        'Filegator\Services\Logger\LoggerInterface' => [
            'handler' => '\Filegator\Services\Logger\Adapters\MonoLogger',
            'config' => [
                'monolog_handlers' => [
                    function () {
                        return new \Monolog\Handler\StreamHandler(
                            __DIR__ . '/private/logs/app.log',
                            \Monolog\Logger::DEBUG
                        );
                    },
                ],
            ],
        ],
        'Filegator\Services\Session\SessionStorageInterface' => [
            'handler' => '\Filegator\Services\Session\Adapters\SessionStorage',
            'config' => [
                // Sessions are kept on the volume rather than in the container's tmp,
                // so a restart of the step does not sign everyone out
                'handler' => function () {
                    $handler = new \Symfony\Component\HttpFoundation\Session\Storage\Handler\NativeFileSessionHandler(
                        __DIR__ . '/private/sessions'
                    );

                    return new \Symfony\Component\HttpFoundation\Session\Storage\NativeSessionStorage([
                        'cookie_samesite' => 'Lax',
                        'cookie_secure' => null,
                        'cookie_httponly' => true,
                    ], $handler);
                },
            ],
        ],
        'Filegator\Services\Cors\Cors' => [
            'handler' => '\Filegator\Services\Cors\Cors',
            'config' => [
                'enabled' => false,
            ],
        ],
        'Filegator\Services\Tmpfs\TmpfsInterface' => [
            'handler' => '\Filegator\Services\Tmpfs\Adapters\Tmpfs',
            'config' => [
                // Upload chunks and batch-download archives land here. On the volume,
                // so a multi-gigabyte transfer is bounded by the volume rather than by
                // whatever the container runtime gives a writable layer.
                'path' => __DIR__ . '/private/tmp/',
                'gc_probability_perc' => 10,
                'gc_older_than' => 60 * 60 * 24 * 2,
            ],
        ],
        'Filegator\Services\Security\Security' => [
            'handler' => '\Filegator\Services\Security\Security',
            'config' => [
                'csrf_protection' => true,
                'csrf_key' => $dx['csrf_key'],
                'ip_allowlist' => [],
                'ip_denylist' => [],
                'allow_insecure_overlays' => false,
            ],
        ],
        'Filegator\Services\View\ViewInterface' => [
            'handler' => '\Filegator\Services\View\Adapters\Vuejs',
            'config' => [
                'add_to_head' => '',
                'add_to_body' => '',
            ],
        ],
        'Filegator\Services\Storage\Filesystem' => [
            'handler' => '\Filegator\Services\Storage\Filesystem',
            'config' => [
                'separator' => '/',
                'config' => [],
                // The engine volume, or the path inside it that ROOT_DIR names —
                // the same directory `dxflow artifact` and the console's Artifacts show
                'adapter' => function () use ($dx) {
                    return new \League\Flysystem\Adapter\Local($dx['root']);
                },
            ],
        ],
        'Filegator\Services\Archiver\ArchiverInterface' => [
            'handler' => '\Filegator\Services\Archiver\Adapters\ZipArchiver',
            'config' => [],
        ],
        'Filegator\Services\Auth\AuthInterface' => [
            'handler' => '\Filegator\Services\Auth\Adapters\JsonFile',
            'config' => [
                'file' => __DIR__ . '/private/users.json',
            ],
        ],
        'Filegator\Services\Router\Router' => [
            'handler' => '\Filegator\Services\Router\Router',
            'config' => [
                'query_param' => 'r',
                'routes_file' => __DIR__ . '/backend/Controllers/routes.php',
            ],
        ],
    ],
];
