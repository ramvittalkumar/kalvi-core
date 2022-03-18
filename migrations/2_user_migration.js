const Migrations = artifacts.require("User");

module.exports = function (deployer) {
  deployer.deploy(Migrations);
};
