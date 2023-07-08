describe('Font-face should works', function () {
  it('support loading font through font-face', async () => {
    const css = `@font-face {
      font-family: Google Sans;
      src: url(/public/assets/OpenSans_Condensed-Bold.ttf);
    }`;
    const style = document.createElement('style');
    style.innerHTML = css;
    document.head.append(style);
    let element = createElement('div', {
      'style': {
        'font-family': 'Google Sans',
        'font-size': '50px'
      }
    }, [
      createText('Hello World')
    ]);
    document.body.appendChild(element);
    await sleep(1);
    await snapshot();
  });
});

describe('Font-face local font should works', function () {
  it('222support loading font through font-face', async () => {
    const css = `@font-face {
      font-family: Google Sans;
    }`;
    const style = document.createElement('style');
    style.innerHTML = css;
    document.head.append(style);
    let element = createElement('div', {
      'style': {
        'font-family': 'Google Sans',
        'font-size': '50px'
      }
    }, [
      createText('信息技术')
    ]);
    document.body.appendChild(element);
    await sleep(1);
    await snapshot();
  });
});