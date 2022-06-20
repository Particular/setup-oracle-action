/******/ (() => { // webpackBootstrap
/******/ 	var __webpack_modules__ = ({

/***/ 105:
/***/ ((module) => {

module.exports = eval("require")("@actions/core");


/***/ }),

/***/ 946:
/***/ ((module) => {

module.exports = eval("require")("@actions/exec");


/***/ }),

/***/ 17:
/***/ ((module) => {

"use strict";
module.exports = require("path");

/***/ })

/******/ 	});
/************************************************************************/
/******/ 	// The module cache
/******/ 	var __webpack_module_cache__ = {};
/******/ 	
/******/ 	// The require function
/******/ 	function __nccwpck_require__(moduleId) {
/******/ 		// Check if module is in cache
/******/ 		var cachedModule = __webpack_module_cache__[moduleId];
/******/ 		if (cachedModule !== undefined) {
/******/ 			return cachedModule.exports;
/******/ 		}
/******/ 		// Create a new module (and put it into the cache)
/******/ 		var module = __webpack_module_cache__[moduleId] = {
/******/ 			// no module.id needed
/******/ 			// no module.loaded needed
/******/ 			exports: {}
/******/ 		};
/******/ 	
/******/ 		// Execute the module function
/******/ 		var threw = true;
/******/ 		try {
/******/ 			__webpack_modules__[moduleId](module, module.exports, __nccwpck_require__);
/******/ 			threw = false;
/******/ 		} finally {
/******/ 			if(threw) delete __webpack_module_cache__[moduleId];
/******/ 		}
/******/ 	
/******/ 		// Return the exports of the module
/******/ 		return module.exports;
/******/ 	}
/******/ 	
/************************************************************************/
/******/ 	/* webpack/runtime/compat */
/******/ 	
/******/ 	if (typeof __nccwpck_require__ !== 'undefined') __nccwpck_require__.ab = __dirname + "/";
/******/ 	
/************************************************************************/
var __webpack_exports__ = {};
// This entry need to be wrapped in an IIFE because it need to be isolated against other modules in the chunk.
(() => {
const path = __nccwpck_require__(17);
const core = __nccwpck_require__(105);
const exec = __nccwpck_require__(946);

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

async function run() {

    try {

        if (!isPost) {

            console.log("Running setup action");

            let random = Math.round(10000000000 * Math.random());
            let containerName = 'psw-oracle-c-' + random;
            let storageName = 'psw-oracle-s-' + random;

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
                    '-Tag', tag
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

})();

module.exports = __webpack_exports__;
/******/ })()
;