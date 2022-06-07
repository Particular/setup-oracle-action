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
let tagName = core.getInput('tag');

async function run() {

    try {

        if (!isPost) {

            console.log("Running setup action");

            let OracleContainerName = 'psw-oracle-' + Math.round(10000000000 * Math.random());
            core.saveState('OracleContainerName', OracleContainerName);

            console.log("OracleContainerName = " + OracleContainerName);

            await exec.exec('pwsh', [
                '-File', setupPs1,
                '-oracleContainerName', OracleContainerName,
                '-connectionStringName', connectionStringName,
                '-tagName', tagName
            ]);

        } else { // Cleanup

            console.log("Running cleanup");

            let OracleContainerName = core.getState('OracleContainerName');

            await exec.exec('pwsh', [
                '-File', cleanupPs1,
                '-OracleContainerName', OracleContainerName
            ]);

        }

    } catch (err) {
        core.setFailed(err);
        console.log(err);
    }

}

run();