module.exports = {
  apps: [{
    name: 'option-learner-guide',
    script: '/usr/bin/node',
    args: '/home/kunkka/projects/option-learner-guide/node_modules/.bin/next start -p 3101',
    cwd: '/home/kunkka/projects/option-learner-guide',
    instances: 1,
    exec_mode: 'fork',
    watch: false,
    max_memory_restart: '500M',
    env: {
      NODE_ENV: 'production',
      PORT: '3101',
      NEXT_TELEMETRY_DISABLED: '1',
      NEXT_PUBLIC_BASE_PATH: '/option-learner-guide'
    },
    error_file: '/var/log/pm2/option-learner-guide.error.log',
    out_file: '/var/log/pm2/option-learner-guide.out.log',
    log_file: '/var/log/pm2/option-learner-guide.log',
    time: true,
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
}
