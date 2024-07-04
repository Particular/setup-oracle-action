const path = require('path');
const core = require('@actions/core');
const exec = require('@actions/exec');

const setupPs1 = path.resolve(__dirname, '../setup.ps1');
const cleanupPs1 = path.resolve(__dirname, '../cleanup.ps1');

console.log('Setup path: ' + setupPs1);
console.log('Cleanup path: ' + cleanupPs1);

// Only one endpoint, so determine if this is the post action, and set it true so that
// the next time we're executed, it goes to the post action
let isPost = core.getState('IsPost');
core.saveState('IsPost', true);

let connectionStringName = core.getInput('connection-string-name');
let tag = core.getInput('tag');
let initScript = core.getInput('init-script');
let registryLoginServer = core.getInput('registry-login-server');
let registryUser = core.getInput('registry-username');
let registryPass = core.getInput('registry-password');

async function run() {

    try {

        if (!isPost) {

            console.log("Running setup action");

            let random = Math.round(10000000000 * Math.random());
            let containerName = 'psw-oracle' + random;
            let storageName = 'psworacle' + random;

            core.saveState('containerName', containerName);
            core.saveState('storageName', storageName);

            console.log("containerName = " + containerName);
            console.log("storageName = " + storageName);

            await exec.exec(
                'pwsh',
                [
                    '-File', setupPs1,
                    '-ContainerName', containerName,
                    '-StorageName', storageName,
                    '-ConnectionStringName', connectionStringName,
                    '-InitScript', initScript,
                    '-Tag', tag,
                    '-RegistryLoginServer', registryLoginServer,
                    '-RegistryUser', registryUser,
                    '-RegistryPass', registryPass                    
                ]);

        } else { // Cleanup

            console.log("Running cleanup");

            let containerName = core.getState('containerName');
            let storageName = core.getState('storageName');

            await exec.exec(
                'pwsh',
                [
                    '-File', cleanupPs1,
                    '-ContainerName', containerName,
                    '-StorageName', storageName
                ]);

        }

    } catch (err) {
        core.setFailed(err);
        console.log(err);
    }

}

run();
