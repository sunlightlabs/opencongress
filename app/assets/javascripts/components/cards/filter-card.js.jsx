/** @jsx React.DOM */

var FilterCard  = React.createClass({

    formHandler: function(e){
      e.preventDefault();
      var formData = $( this.refs.form.getDOMNode() ).serialize();
      this.props.onSearch( formData, this.props.url );

      this.refs.sponsor_id.getDOMNode().value = '';
    },

    render: function () {
        return (
            <div className="contents__side">
              <form ref="form" method="get" action={this.props.url} onSubmit={this.formHandler}>
                <input type="text" name="sponsor_id" ref="sponsor_id" />
                <input type="submit" />
              </form>
            </div>
        );
    }
});