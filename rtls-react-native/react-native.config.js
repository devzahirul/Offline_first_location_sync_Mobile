module.exports = {
  dependency: {
    platforms: {
      android: {
        sourceDir: './android',
        packageImportPath: 'import com.rtls.reactnative.RTLSyncPackage;',
        packageInstance: 'new RTLSyncPackage()',
      },
      ios: {},
    },
  },
};
